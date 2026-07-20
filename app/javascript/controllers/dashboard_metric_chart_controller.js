import { Controller } from "@hotwired/stimulus"

let chartLibraryPromise

function loadChartLibrary() {
  chartLibraryPromise ||= import("chart.js").then(() => {
    if (!globalThis.Chart) throw new Error("Chart.js did not initialize")

    return globalThis.Chart
  })

  return chartLibraryPromise
}

export default class extends Controller {
  static targets = [ "canvas" ]
  static values = {
    values: Array,
    baselineAverage: Number,
    scaleMin: Number,
    scaleMax: Number,
    direction: String
  }

  connect() {
    this.connectionToken = Symbol("dashboard-metric-chart")
    this.renderChart(this.connectionToken)
  }

  disconnect() {
    this.connectionToken = null
    this.destroyChart()
  }

  async renderChart(connectionToken) {
    try {
      const Chart = await loadChartLibrary()

      if (this.connectionToken !== connectionToken || !this.element.isConnected || !this.hasCanvasTarget) return

      const values = this.numericValues()
      if (values.length === 0) return

      this.destroyChart()
      this.chart = new Chart(this.canvasTarget, this.chartConfiguration(values))
    } catch (error) {
      if (this.connectionToken === connectionToken) {
        console.error("Unable to render dashboard metric chart", error)
      }
    }
  }

  destroyChart() {
    this.chart?.destroy()
    this.chart = null
  }

  numericValues() {
    if (!this.hasValuesValue) return []

    const values = this.valuesValue.map((value) => Number(value))
    return values.every(Number.isFinite) ? values : []
  }

  chartConfiguration(values) {
    const colors = this.chartColors()
    const [scaleMinimum, scaleMaximum] = this.scaleBounds(values)
    const currentIndex = values.length - 1

    return {
      type: "line",
      data: {
        labels: values.map((_, index) => index),
        datasets: [
          {
            data: values.map(() => this.baselineAverageValue),
            borderColor: this.withAlpha(colors.baseline, 0.22),
            borderDash: [ 4, 5 ],
            borderWidth: 1,
            pointRadius: 0,
            pointHitRadius: 0,
            fill: false,
            tension: 0,
            order: 1
          },
          {
            data: values,
            borderColor: this.withAlpha(colors.trend, 0.5),
            backgroundColor: (context) => this.areaGradient(context, colors.trend),
            borderCapStyle: "round",
            borderJoinStyle: "round",
            borderWidth: 2,
            cubicInterpolationMode: "monotone",
            tension: 0.22,
            fill: "start",
            pointRadius: (context) => context.dataIndex === currentIndex ? 2.5 : 0,
            pointHoverRadius: 0,
            pointHitRadius: 0,
            pointBackgroundColor: colors.surface,
            pointBorderColor: this.withAlpha(colors.trend, 0.72),
            pointBorderWidth: (context) => context.dataIndex === currentIndex ? 1.5 : 0,
            order: 0
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        animations: false,
        events: [],
        interaction: { mode: null },
        normalized: true,
        layout: {
          padding: { top: 5, right: 4, bottom: 5, left: 2 }
        },
        plugins: {
          legend: { display: false },
          tooltip: { enabled: false }
        },
        scales: {
          x: {
            display: false,
            offset: false,
            grid: { display: false },
            border: { display: false }
          },
          y: {
            display: false,
            min: scaleMinimum,
            max: scaleMaximum,
            grid: { display: false },
            border: { display: false }
          }
        }
      }
    }
  }

  scaleBounds(values) {
    const minimum = this.hasScaleMinValue ? this.scaleMinValue : Math.min(...values)
    const maximum = this.hasScaleMaxValue ? this.scaleMaxValue : Math.max(...values)

    if (minimum !== maximum) return [ minimum, maximum ]

    // Keep an all-zero trace low in the card instead of striking through its value.
    if (minimum === 0) return [ 0, 1 ]

    const padding = Math.abs(minimum) * 0.08 || 1
    return [ minimum - padding, maximum + padding ]
  }

  chartColors() {
    const styles = getComputedStyle(this.element)
    const direction = { up: "up", new: "up", down: "down", same: "neutral" }[this.directionValue] || "neutral"

    return {
      trend: styles.getPropertyValue(`--rn-chart-${direction}`).trim() || "#78716c",
      baseline: styles.getPropertyValue("--rn-muted").trim() || "#697169",
      surface: styles.getPropertyValue("--rn-surface").trim() || "#fffefa"
    }
  }

  areaGradient(context, color) {
    const { chartArea, ctx } = context.chart
    if (!chartArea) return this.withAlpha(color, 0.08)

    const gradient = ctx.createLinearGradient(0, chartArea.top, 0, chartArea.bottom)
    gradient.addColorStop(0, this.withAlpha(color, 0.13))
    gradient.addColorStop(0.72, this.withAlpha(color, 0.04))
    gradient.addColorStop(1, this.withAlpha(color, 0))
    return gradient
  }

  withAlpha(color, alpha) {
    const value = color.trim()
    const shortHex = value.match(/^#([\da-f])([\da-f])([\da-f])$/i)
    const hex = shortHex ? `#${shortHex[1]}${shortHex[1]}${shortHex[2]}${shortHex[2]}${shortHex[3]}${shortHex[3]}` : value
    const hexMatch = hex.match(/^#([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i)

    if (hexMatch) {
      const channels = hexMatch.slice(1).map((channel) => parseInt(channel, 16))
      return `rgba(${channels.join(", ")}, ${alpha})`
    }

    const rgbMatch = value.match(/^rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)/i)
    if (rgbMatch) return `rgba(${rgbMatch.slice(1, 4).join(", ")}, ${alpha})`

    return value
  }
}
