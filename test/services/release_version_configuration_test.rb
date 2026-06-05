require "minitest/autorun"
require "pathname"
require "yaml"

class ReleaseVersionConfigurationTest < Minitest::Test
  ROOT = Pathname.new(File.expand_path("../..", __dir__))

  def test_release_container_image_bakes_release_tag_as_default_app_version
    dockerfile = ROOT.join("Dockerfile").read

    assert_match(/^ARG ROASTNODE_VERSION=development$/, dockerfile)
    assert_match(/FROM docker\.io\/library\/ruby:\$RUBY_VERSION-slim AS base\nARG ROASTNODE_VERSION/, dockerfile)
    assert_match(/ROASTNODE_VERSION="\$\{ROASTNODE_VERSION\}"/, dockerfile)

    workflow = YAML.load_file(ROOT.join(".github/workflows/release-container.yml"), aliases: true)
    build_step = workflow.fetch("jobs").fetch("publish").fetch("steps").find { |step| step["name"] == "Build and push image" }

    assert_equal "docker/build-push-action@v6", build_step.fetch("uses")
    assert_includes build_step.fetch("with").fetch("build-args"), "ROASTNODE_VERSION=${{ env.RELEASE_TAG }}"
  end
end
