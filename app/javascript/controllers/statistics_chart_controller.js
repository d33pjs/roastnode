import { Controller } from "@hotwired/stimulus"

let chartLibraryPromise

function loadChartLibrary() {
  chartLibraryPromise ||= import("chart.js").then(() => {
    if (!globalThis.Chart) throw new Error("Chart.js did not initialize")

    return globalThis.Chart
  }).catch((error) => {
    chartLibraryPromise = null
    throw error
  })

  return chartLibraryPromise
}

export default class extends Controller {
  static targets = [ "canvas", "frame", "status", "fallback", "swatch" ]
  static values = { series: Object, error: String, axisLabel: String }

  connect() {
    this.connectionToken = Symbol("statistics-chart")
    this.statusTarget.hidden = false
    this.themeObserver = new MutationObserver(() => this.renderChart(this.connectionToken))
    this.themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: [ "class" ] })
    this.renderChart(this.connectionToken)
  }

  disconnect() {
    this.connectionToken = null
    this.renderToken = null
    this.themeObserver?.disconnect()
    this.destroyChart()
    this.frameTarget.hidden = true
    this.statusTarget.hidden = true
  }

  async renderChart(connectionToken) {
    const renderToken = this.renderToken = Symbol("statistics-chart-render")

    try {
      const Chart = await loadChartLibrary()
      if (this.connectionToken !== connectionToken || this.renderToken !== renderToken || !this.element.isConnected) return

      this.destroyChart()
      if (!this.seriesValue.labels.length) {
        this.frameTarget.hidden = true
        this.statusTarget.hidden = true
        return
      }

      // Reveal the parent before Chart.js measures it. Exact HTML counts stay available.
      this.frameTarget.hidden = false
      this.chart = new Chart(this.canvasTarget, this.chartConfiguration())
      this.statusTarget.hidden = true
    } catch (_error) {
      if (this.connectionToken !== connectionToken || this.renderToken !== renderToken) return

      this.destroyChart()
      this.frameTarget.hidden = true
      this.statusTarget.textContent = this.errorValue
      this.statusTarget.hidden = false
      this.fallbackTarget.open = true
    }
  }

  destroyChart() {
    this.chart?.destroy()
    this.chart = null
  }

  tooltipLines(value, chart, weight = "normal") {
    const maximumWidth = Math.max(24, Math.min(chart.width - 48, 360))
    const lines = []
    let line = ""
    chart.ctx.save()
    chart.ctx.font = `${weight} 12px ${getComputedStyle(this.element).fontFamily}`

    // Measure actual glyph widths; split unbroken names without truncating them.
    for (const character of value.trim()) {
      if (line && chart.ctx.measureText(line + character).width > maximumWidth) {
        const space = line.lastIndexOf(" ")
        if (space > 0) {
          lines.push(line.slice(0, space))
          line = line.slice(space + 1) + character
        } else {
          lines.push(line)
          line = character
        }
      } else {
        line += character
      }
    }

    if (line.trim()) lines.push(line.trim())
    chart.ctx.restore()
    return lines
  }

  chartConfiguration() {
    const styles = getComputedStyle(this.element)
    const ink = styles.getPropertyValue("--rn-ink").trim()
    const muted = styles.getPropertyValue("--rn-muted").trim()
    const line = styles.getPropertyValue("--rn-line").trim()
    const surface = styles.getPropertyValue("--rn-surface").trim()
    const font = styles.fontFamily
    const labels = this.seriesValue.labels

    return {
      type: "bar",
      data: {
        labels: [ ...labels ],
        datasets: this.seriesValue.datasets.map((dataset, index) => ({
          label: dataset.label,
          data: [ ...dataset.data ],
          backgroundColor: getComputedStyle(this.swatchTargets[index]).backgroundColor,
          borderColor: surface,
          borderWidth: 1,
          borderSkipped: false,
          maxBarThickness: 28
        }))
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        interaction: { mode: "nearest", intersect: true },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: surface,
            titleColor: ink,
            bodyColor: ink,
            borderColor: line,
            borderWidth: 1,
            titleFont: { family: font, size: 12, weight: "bold" },
            bodyFont: { family: font, size: 12, weight: "normal" },
            callbacks: {
              title: (items) => this.tooltipLines(labels[items[0].dataIndex], items[0].chart, "bold"),
              label: (item) => [ ...this.tooltipLines(item.dataset.label, item.chart), item.formattedValue ]
            }
          }
        },
        scales: {
          x: {
            stacked: true,
            beginAtZero: true,
            border: { display: false },
            grid: { color: line },
            ticks: { precision: 0, color: muted, font: { family: font }, maxTicksLimit: 6 },
            title: { display: true, text: this.axisLabelValue, color: muted, font: { family: font } }
          },
          y: {
            stacked: true,
            border: { display: false },
            grid: { display: false },
            ticks: {
              autoSkip: false,
              color: ink,
              font: { family: font, weight: "600" },
              callback: (_value, index) => {
                const label = labels[index]
                return label.length > 22 ? `${label.slice(0, 21)}…` : label
              }
            }
          }
        }
      }
    }
  }
}
