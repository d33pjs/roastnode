import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import vm from "node:vm"

// Execute the real controller with only its browser/library boundaries replaced.
const source = readFileSync(new URL("../../app/javascript/controllers/statistics_chart_controller.js", import.meta.url), "utf8")
  .replace('import { Controller } from "@hotwired/stimulus"', "class Controller {}")
  .replace('import("chart.js")', "importChart()")
  .replace("export default class", "globalThis.StatisticsChartController = class")

function harness({ loader = () => Promise.resolve() } = {}) {
  const charts = []
  const observers = []
  const root = {}
  const styles = {
    "--rn-ink": "#23231f", "--rn-muted": "#697169", "--rn-line": "#d7dfd8", "--rn-surface": "#fffefa"
  }
  const sandbox = {
    document: { documentElement: root },
    importChart: loader,
    getComputedStyle: (element) => ({
      fontFamily: "Elms Sans",
      backgroundColor: element.color,
      getPropertyValue: (name) => styles[name]
    }),
    MutationObserver: class {
      constructor(callback) { this.callback = callback; observers.push(this) }
      observe(element, options) { this.element = element; this.options = options }
      disconnect() { this.disconnected = true }
    },
    Chart: class {
      constructor(canvas, configuration) {
        this.canvas = canvas
        this.configuration = configuration
        this.destroyed = false
        this.width = 301
        this.ctx = {
          font: "original canvas font",
          save() { this.savedFont = this.font },
          restore() { this.font = this.savedFont },
          measureText(text) {
            return { width: [ ...text ].reduce((width, character) => width + (character === "W" ? 14 : 7), 0) }
          }
        }
        charts.push(this)
      }
      destroy() { this.destroyed = true }
    }
  }
  vm.runInNewContext(source, sandbox)
  const controller = new sandbox.StatisticsChartController()
  Object.assign(controller, {
    element: { isConnected: true },
    canvasTarget: {},
    frameTarget: { hidden: true },
    statusTarget: { hidden: true, textContent: "Loading" },
    fallbackTarget: { open: true },
    swatchTargets: [ { color: "rgb(47, 83, 101)" }, { color: "rgb(4, 120, 87)" } ],
    seriesValue: {
      labels: [ "Same name", "Same name", "A household member with a long name" ],
      datasets: [ { label: "Same name", data: [ 3, 0, 1 ] }, { label: "Same name", data: [ 1, 2, 0 ] } ]
    },
    axisLabelValue: "coffees",
    errorValue: "The chart could not load. All pairing counts are available below."
  })
  return { controller, charts, observers, styles, root }
}

async function flush() {
  for (let index = 0; index < 8; index++) await Promise.resolve()
}

test("renders stacked horizontal bars without combining duplicate labels or mutating server data", async () => {
  const { controller, charts, observers, root } = harness()
  const original = JSON.stringify(controller.seriesValue)
  controller.connect()
  await flush()

  assert.equal(charts.length, 1)
  const config = charts[0].configuration
  assert.equal(config.type, "bar")
  assert.equal(config.options.indexAxis, "y")
  assert.equal(config.options.scales.x.stacked, true)
  assert.equal(config.options.scales.y.stacked, true)
  assert.equal(config.options.scales.x.ticks.precision, 0)
  assert.equal(config.options.maintainAspectRatio, false)
  assert.equal(config.options.animation, false)
  assert.equal(config.data.labels.length, 3)
  assert.equal(config.data.datasets.length, 2)
  assert.equal(config.data.datasets[1].data[1], 2)
  assert.equal(config.data.datasets[0].backgroundColor, "rgb(47, 83, 101)")
  config.data.datasets[0].data[0] = 99
  assert.equal(JSON.stringify(controller.seriesValue), original)
  assert.equal(config.options.scales.y.ticks.callback(null, 2), "A household member wi…")
  assert.equal(config.options.plugins.tooltip.callbacks.title([{ dataIndex: 2, chart: charts[0] }]).join(" "), controller.seriesValue.labels[2])
  assert.equal(controller.frameTarget.hidden, false)
  assert.equal(controller.statusTarget.hidden, true)
  assert.equal(controller.fallbackTarget.open, true)
  assert.equal(observers[0].element, root)
})

test("tooltips wrap long names within the current canvas width and keep counts on their own line", async () => {
  const { controller, charts } = harness()
  const maker = "W".repeat(70)
  const recipient = "A guest with a long household name and a very long surname"
  controller.seriesValue.labels[0] = maker
  controller.seriesValue.datasets[0].label = recipient
  controller.connect()
  await flush()

  const chart = charts[0]
  const callbacks = chart.configuration.options.plugins.tooltip.callbacks
  const item = { chart, dataIndex: 0, dataset: controller.seriesValue.datasets[0], formattedValue: "1,234" }
  const titleLines = callbacks.title([ item ])
  const bodyLines = callbacks.label(item)
  assert.ok(titleLines.length > 1)
  assert.ok(bodyLines.length > 2)
  assert.equal(titleLines.join(""), maker)
  assert.equal(bodyLines.slice(0, -1).join(" "), recipient)
  assert.equal(bodyLines.at(-1), "1,234")
  for (const line of [ ...titleLines, ...bodyLines ]) {
    assert.ok(chart.ctx.measureText(line).width <= chart.width - 48, `Tooltip line overflows: ${line}`)
  }
  assert.equal(chart.ctx.font, "original canvas font")

  chart.width = 220
  const narrowerLines = callbacks.title([ item ])
  assert.ok(narrowerLines.length > titleLines.length)
  assert.equal(narrowerLines.join(""), maker)
  for (const line of narrowerLines) {
    assert.ok(chart.ctx.measureText(line).width <= chart.width - 48)
  }
})

test("rebuilds colors on theme changes and destroys chart and observer on Turbo disconnect", async () => {
  const { controller, charts, observers, styles } = harness()
  controller.connect()
  await flush()
  styles["--rn-ink"] = "#f1f3ea"
  controller.swatchTargets[0].color = "rgb(182, 202, 200)"
  observers[0].callback()
  await flush()

  assert.equal(charts.length, 2)
  assert.equal(charts[0].destroyed, true)
  assert.equal(charts[1].configuration.options.scales.y.ticks.color, "#f1f3ea")
  assert.equal(charts[1].configuration.data.datasets[0].backgroundColor, "rgb(182, 202, 200)")
  controller.disconnect()
  assert.equal(charts[1].destroyed, true)
  assert.equal(observers[0].disconnected, true)
  assert.equal(controller.frameTarget.hidden, true)
})

test("does not create a chart after a pending import outlives disconnect", async () => {
  let resolve
  const { controller, charts } = harness({ loader: () => new Promise((done) => { resolve = done }) })
  controller.connect()
  controller.disconnect()
  resolve()
  await flush()
  assert.equal(charts.length, 0)
  assert.equal(controller.statusTarget.hidden, true)
})

test("only the newest render may finish when connect and theme updates race", async () => {
  let resolve
  const { controller, charts, observers } = harness({ loader: () => new Promise((done) => { resolve = done }) })
  controller.connect()
  observers[0].callback()
  observers[0].callback()
  resolve()
  await flush()
  assert.equal(charts.length, 1)
})

test("failed imports expose exact HTML counts and can recover on reconnect", async () => {
  let attempts = 0
  const { controller, charts } = harness({ loader: () => ++attempts === 1 ? Promise.reject(new Error("Unavailable")) : Promise.resolve() })
  controller.fallbackTarget.open = false
  controller.connect()
  await flush()
  assert.equal(charts.length, 0)
  assert.equal(controller.frameTarget.hidden, true)
  assert.equal(controller.statusTarget.textContent, controller.errorValue)
  assert.equal(controller.statusTarget.hidden, false)
  assert.equal(controller.fallbackTarget.open, true)

  controller.disconnect()
  controller.connect()
  await flush()
  assert.equal(charts.length, 1)
  assert.equal(controller.statusTarget.hidden, true)
})

test("empty data never produces an empty chart or hides HTML counts", async () => {
  const { controller, charts } = harness()
  controller.seriesValue = { labels: [], datasets: [] }
  controller.connect()
  await flush()
  assert.equal(charts.length, 0)
  assert.equal(controller.frameTarget.hidden, true)
  assert.equal(controller.statusTarget.hidden, true)
  assert.equal(controller.fallbackTarget.open, true)
})
