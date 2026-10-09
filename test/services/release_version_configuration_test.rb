require "minitest/autorun"
require "bundler"
require "pathname"
require "yaml"

class ReleaseVersionConfigurationTest < Minitest::Test
  ROOT = Pathname.new(File.expand_path("../..", __dir__))

  def test_release_builder_uses_public_cache_before_pulling_qemu_and_for_buildkit
    workflow = YAML.load_file(ROOT.join(".github/workflows/release-container.yml"), aliases: true)
    steps = workflow.fetch("jobs").fetch("publish").fetch("steps")
    cache_index = steps.index { |step| step["name"] == "Configure public Docker Hub cache" }
    qemu_index = steps.index { |step| step["name"] == "Set up QEMU" }
    refute_nil cache_index, "Host pulls must use the public cache before QEMU setup"
    assert_operator cache_index, :<, qemu_index
    assert_includes steps[cache_index].fetch("run"), 'config["registry-mirrors"]'
    assert_includes steps[cache_index].fetch("run"), "https://mirror.gcr.io"
    assert_includes steps[cache_index].fetch("run"), "sudo systemctl restart docker"
    buildx = steps.find { |step| step["name"] == "Set up Docker Buildx" }
    assert_includes buildx.fetch("with").fetch("buildkitd-config-inline"), '[registry."docker.io"]'
    assert_includes buildx.fetch("with").fetch("buildkitd-config-inline"), 'mirrors = ["mirror.gcr.io"]'
  end

  def test_release_container_image_bakes_release_tag_as_default_app_version
    dockerfile = ROOT.join("Dockerfile").read

    assert_match(/^ARG ROASTNODE_VERSION=development$/, dockerfile)
    assert_match(/FROM docker\.io\/library\/ruby:\$RUBY_VERSION-slim AS base\nARG ROASTNODE_VERSION/, dockerfile)
    assert_match(/ROASTNODE_VERSION="\$\{ROASTNODE_VERSION\}"/, dockerfile)
    assert_equal ROOT.join(".ruby-version").read.strip, dockerfile[/^ARG RUBY_VERSION=(.+)$/, 1]

    workflow = YAML.load_file(ROOT.join(".github/workflows/release-container.yml"), aliases: true)
    build_step = workflow.fetch("jobs").fetch("publish").fetch("steps").find { |step| step["name"] == "Build and push image" }

    assert_match(/\Adocker\/build-push-action@[0-9a-f]{40}\z/, build_step.fetch("uses"))
    assert_includes build_step.fetch("with").fetch("build-args"), "ROASTNODE_VERSION=${{ env.RELEASE_TAG }}"
    metadata_step = workflow.fetch("jobs").fetch("publish").fetch("steps").find { |step| step["name"] == "Extract Docker metadata" }
    assert_includes metadata_step.fetch("with").fetch("labels"), "org.opencontainers.image.revision=${{ steps.source.outputs.sha }}"
  end

  def test_external_workflow_actions_are_pinned_to_immutable_commits
    workflow_paths = ROOT.glob("{.github,.gitea}/workflows/*.{yml,yaml}")

    workflow_paths.each do |path|
      workflow = YAML.load_file(path, aliases: true)
      workflow.fetch("jobs").each_value do |job|
        job.fetch("steps", []).each do |step|
          action = step["uses"]
          next unless action
          next if action.start_with?("./")

          assert_match(/@[0-9a-f]{40}\z/, action, "#{path.relative_path_from(ROOT)} must pin #{action} to a full commit SHA")
        end
      end
    end
  end

  def test_postgresql_image_patch_is_consistent_across_runtime_and_ci_defaults
    selected_image = "postgres:17.11"

    development_compose = YAML.load_file(ROOT.join("compose.yaml"), aliases: true)
    production_compose = YAML.load_file(ROOT.join("deploy/compose.production.yml"), aliases: true)
    gitea_ci = YAML.load_file(ROOT.join(".gitea/workflows/ci.yml"), aliases: true)
    production_env = ROOT.join("deploy/production.env.example").read

    assert_equal selected_image, development_compose.fetch("services").fetch("postgres").fetch("image")
    assert_equal "${POSTGRES_IMAGE:-#{selected_image}}", production_compose.fetch("services").fetch("postgres").fetch("image")
    assert_equal selected_image, production_env[/^POSTGRES_IMAGE=(.+)$/, 1]
    assert_equal selected_image, gitea_ci.fetch("jobs").fetch("ci").fetch("services").fetch("postgres").fetch("image")
  end

  def test_dependency_audit_package_counts_match_the_lockfile
    lockfile = Bundler::LockfileParser.new(ROOT.join("Gemfile.lock").read)
    spec_names = lockfile.specs.map(&:name).uniq
    dependency_names = lockfile.dependencies.keys
    locked_direct_names = spec_names & dependency_names
    transitive_names = spec_names - dependency_names
    unlocked_declaration_names = dependency_names - spec_names
    audit = ROOT.join("security-report/dependency-audit.md").read

    assert_equal [ "tzinfo-data" ], unlocked_declaration_names
    assert_includes audit,
      "- Ruby packages: #{spec_names.size} unique locked specs: #{dependency_names.size} Gemfile declarations, " \
      "#{locked_direct_names.size} locked direct specs, and #{transitive_names.size} transitive specs. " \
      "`tzinfo-data` is declared but not locked for the selected platforms."
  end
end
