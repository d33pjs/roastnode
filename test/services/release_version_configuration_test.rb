require "minitest/autorun"
require "bundler"
require "pathname"
require "yaml"

class ReleaseVersionConfigurationTest < Minitest::Test
  ROOT = Pathname.new(File.expand_path("../..", __dir__))

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
    total_count = lockfile.specs.map(&:name).uniq.size
    direct_count = lockfile.dependencies.size
    transitive_count = total_count - direct_count
    audit = ROOT.join("security-report/dependency-audit.md").read

    assert_includes audit,
      "- Ruby packages: #{total_count} unique locked specs (#{direct_count} direct declarations, #{transitive_count} transitive)."
  end
end
