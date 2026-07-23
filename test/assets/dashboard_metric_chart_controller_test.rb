require "test_helper"

class DashboardMetricChartControllerTest < ActiveSupport::TestCase
  test "metric chart loads local Chart.js lazily and configures a decorative sparkline" do
    source = Rails.root.join("app/javascript/controllers/dashboard_metric_chart_controller.js").read
    importmap = Rails.root.join("config/importmap.rb").read
    vendored_chart = Rails.root.join("vendor/javascript/chart.js.js").read
    third_party_licenses = Rails.root.join("vendor/javascript/THIRD_PARTY_LICENSES.md").read

    assert_includes importmap, 'pin "chart.js", preload: false # @4.5.1'
    assert_includes vendored_chart, "Chart.js v4.5.1"
    assert_includes third_party_licenses, "Chart.js 4.5.1"
    assert_includes third_party_licenses, "Copyright (c) 2014-2024 Chart.js Contributors"
    assert_includes third_party_licenses, "@kurkle/color 0.3.2"
    assert_includes third_party_licenses, "Copyright (c) 2018-2024 Jukka Kurkela"
    assert_not_includes importmap, "https://"
    assert_includes source, 'import("chart.js")'
    assert_not_includes source, 'from "chart.js"'
    assert_includes source, "globalThis.Chart"
    assert_includes source, "responsive: true"
    assert_includes source, "maintainAspectRatio: false"
    assert_includes source, "animation: false"
    assert_includes source, "events: []"
    assert_includes source, "legend: { display: false }"
    assert_includes source, "tooltip: { enabled: false }"
    assert_includes source, 'cubicInterpolationMode: "monotone"'
    assert_includes source, "createLinearGradient"
  end

  test "metric chart preserves shared scale and cleans up across Turbo disconnects" do
    source = Rails.root.join("app/javascript/controllers/dashboard_metric_chart_controller.js").read

    assert_includes source, "scaleMin: Number"
    assert_includes source, "scaleMax: Number"
    assert_includes source, "if (minimum !== maximum) return [ minimum, maximum ]"
    assert_includes source, "this.connectionToken !== connectionToken"
    assert_includes source, "this.chart?.destroy()"
    assert_includes source, "this.connectionToken = null"
  end
end
