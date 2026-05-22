(function() {
  const chartRegistry = {}

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }

  function titleize(value) {
    return value.replaceAll("_", " ").replace(/\b\w/g, function(match) { return match.toUpperCase() })
  }

  function heightPercent(value, max) {
    if (!max) return 0
    return Math.max((value / max) * 100, value > 0 ? 8 : 0)
  }

  function pathForPoints(points, accessor, width, height, max) {
    return points.map(function(point, index) {
      const x = points.length === 1 ? width / 2 : (index / (points.length - 1)) * width
      const y = height - ((point[accessor] || 0) / max) * height
      return `${index === 0 ? "M" : "L"} ${x.toFixed(2)} ${y.toFixed(2)}`
    }).join(" ")
  }

  function areaPathForPoints(points, accessor, width, height, max) {
    const line = pathForPoints(points, accessor, width, height, max)
    const endX = points.length === 1 ? width / 2 : width
    return `${line} L ${endX.toFixed(2)} ${height} L 0 ${height} Z`
  }

  function formatTimestamp(timestamp) {
    return new Date(timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" })
  }

  function formatLatency(seconds) {
    if (seconds < 60) return seconds + "s"
    if (seconds < 3600) return Math.floor(seconds / 60) + "m"
    return Math.floor(seconds / 3600) + "h"
  }

  function hasChartJs() {
    return typeof window.Chart !== "undefined"
  }

  function buildChartJsConfig(chart, config) {
    return {
      type: "line",
      data: {
        labels: chart.points.map(function(point) { return point.label }),
        datasets: config.series.map(function(series) {
          return {
            label: series.label,
            data: chart.points.map(function(point) { return point[series.key] || 0 }),
            borderColor: series.stroke,
            backgroundColor: series.fill,
            pointBackgroundColor: series.stroke,
            pointBorderColor: "#ffffff",
            pointBorderWidth: 2,
            pointRadius: 3,
            pointHoverRadius: 5,
            borderWidth: 3,
            fill: true,
            tension: 0.35
          }
        })
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false
        },
        plugins: {
          legend: {
            display: true,
            position: "bottom",
            labels: {
              usePointStyle: true,
              boxWidth: 10,
              boxHeight: 10,
              padding: 18,
              color: "#6a7387",
              font: {
                family: "\"IBM Plex Sans\", \"Avenir Next\", sans-serif",
                size: 13
              }
            }
          },
          tooltip: {
            backgroundColor: "rgba(28, 35, 51, 0.94)",
            titleColor: "#ffffff",
            bodyColor: "rgba(255, 255, 255, 0.86)",
            padding: 12,
            displayColors: true
          }
        },
        scales: {
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: "#6a7387",
              maxRotation: 0,
              autoSkip: true
            },
            border: {
              display: false
            }
          },
          y: {
            beginAtZero: true,
            ticks: {
              precision: 0,
              color: "#6a7387"
            },
            grid: {
              color: "rgba(28, 35, 51, 0.1)"
            },
            border: {
              display: false
            }
          }
        }
      }
    }
  }

  function renderChartJsMount(key) {
    return `
      <div class="chartjs-shell">
        <canvas data-chartjs-key="${key}"></canvas>
      </div>
    `
  }

  function mountChartJs(root, key, chart, config) {
    const canvas = root.querySelector(`[data-chartjs-key="${key}"]`)
    if (!canvas || !hasChartJs()) return

    chartRegistry[key] = new window.Chart(canvas, buildChartJsConfig(chart, config))
  }

  function ensureChartJs(root, key, chart, config) {
    if (!hasChartJs()) return false

    if (!chartRegistry[key]) {
      const container = root.querySelector(`[data-backline-dashboard-target="${key}"]`)
      if (!container) return false

      container.innerHTML = renderChartJsMount(key)
      mountChartJs(root, key, chart, config)
      return true
    }

    return false
  }

  function updateChartJs(key, chart, config) {
    const instance = chartRegistry[key]
    if (!instance) return

    instance.data.labels = chart.points.map(function(point) { return point.label })
    instance.data.datasets = config.series.map(function(series, index) {
      const existing = instance.data.datasets[index] || {}

      return Object.assign(existing, {
        label: series.label,
        data: chart.points.map(function(point) { return point[series.key] || 0 }),
        borderColor: series.stroke,
        backgroundColor: series.fill,
        pointBackgroundColor: series.stroke
      })
    })

    instance.options.animation = false
    instance.update("none")
  }

  function renderLineChart(chart, config) {
    if (!chart || !chart.points || !chart.points.length) {
      return '<p class="empty-state">No chart data available yet.</p>'
    }

    const width = 640
    const height = 220
    const max = Math.max(chart.max || 0, 1)
    const points = chart.points
    const hotspots = points.map(function(point, index) {
      const x = points.length === 1 ? width / 2 : (index / (points.length - 1)) * width
      const values = config.series.map(function(series) {
        return `${series.label}: ${point[series.key] || 0}`
      }).join(" • ")

      return `
        <button
          type="button"
          class="line-chart-hotspot"
          style="left:${(x / width) * 100}%"
          data-label="${escapeHtml(point.label)}"
          data-values="${escapeHtml(values)}"
          aria-label="${escapeHtml(point.label + " " + values)}"
        ></button>
      `
    }).join("")

    return `
      <div class="line-chart" data-line-chart>
        <div class="line-chart-tooltip" data-line-chart-tooltip hidden></div>
        <svg class="line-chart-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="${escapeHtml(config.title)}">
          <g class="line-chart-grid">
            <line x1="0" y1="${height}" x2="${width}" y2="${height}"></line>
            <line x1="0" y1="${height * 0.66}" x2="${width}" y2="${height * 0.66}"></line>
            <line x1="0" y1="${height * 0.33}" x2="${width}" y2="${height * 0.33}"></line>
            <line x1="0" y1="0" x2="${width}" y2="0"></line>
          </g>
          ${config.series.map(function(series) {
            return `
              <path class="line-chart-area ${series.css}" d="${areaPathForPoints(points, series.key, width, height, max)}"></path>
              <path class="line-chart-path ${series.css}" d="${pathForPoints(points, series.key, width, height, max)}"></path>
            `
          }).join("")}
          ${config.series.map(function(series) {
            return points.map(function(point, index) {
              const x = points.length === 1 ? width / 2 : (index / (points.length - 1)) * width
              const y = height - ((point[series.key] || 0) / max) * height
              return `<circle class="line-chart-point ${series.css}" cx="${x.toFixed(2)}" cy="${y.toFixed(2)}" r="3.5"></circle>`
            }).join("")
          }).join("")}
        </svg>
        <div class="line-chart-hotspots">${hotspots}</div>
        <div class="line-chart-axis">
          <span>${escapeHtml(points[0].label)}</span>
          <span>${escapeHtml(points[Math.floor(points.length / 2)].label)}</span>
          <span>${escapeHtml(points[points.length - 1].label)}</span>
        </div>
      </div>
      <div class="chart-legend">
        ${config.series.map(function(series) {
          return `<span><i class="legend ${series.css}"></i>${series.label}</span>`
        }).join("")}
      </div>
    `
  }

  function renderBars(points, entries) {
    return `
      <div class="chart-bars">
        ${points.map(function(point) {
          return `
            <div class="chart-group">
              <div class="chart-stack">
                ${entries.map(function(entry) {
                  return `<span class="chart-bar ${entry.css}" style="height:${heightPercent(point[entry.key], point._max)}%"></span>`
                }).join("")}
              </div>
              <small>${escapeHtml(point.label)}</small>
            </div>
          `
        }).join("")}
      </div>
    `
  }

  function renderThroughputChart(chart) {
    if (hasChartJs()) {
      return renderChartJsMount("throughput")
    }

    return renderLineChart(chart, {
      title: "Execution throughput",
      series: [
        { key: "queued", css: "queued", label: "Queued", stroke: "#f0b35b", fill: "rgba(240, 179, 91, 0.12)" },
        { key: "succeeded", css: "succeeded", label: "Succeeded", stroke: "#1f8f54", fill: "rgba(31, 143, 84, 0.12)" },
        { key: "failed", css: "failed", label: "Failed", stroke: "#b33a32", fill: "rgba(179, 58, 50, 0.10)" }
      ]
    })
  }

  function renderHistoryChart(chart) {
    if (!chart || !chart.points || !chart.points.length) {
      return '<p class="empty-state">No historical job data yet.</p>'
    }

    if (hasChartJs()) {
      return renderChartJsMount("history")
    }

    return renderLineChart(chart, {
      title: "History",
      series: [
        { key: "processed", css: "succeeded", label: "Processed", stroke: "#1f8f54", fill: "rgba(31, 143, 84, 0.12)" },
        { key: "failed", css: "failed", label: "Failed", stroke: "#b33a32", fill: "rgba(179, 58, 50, 0.10)" }
      ]
    })
  }

  function renderStatusChart(chart) {
    if (!chart.total) {
      return '<p class="empty-state">No jobs have been recorded yet.</p>'
    }

    return `
      <div class="status-chart">
        ${chart.slices.map(function(slice) {
          return `
            <div class="status-row">
              <div class="status-row-label">
                <strong>${titleize(slice.status)}</strong>
                <span>${slice.value} jobs</span>
              </div>
              <div class="status-progress">
                <span class="status-progress-fill ${slice.status}" style="width:${slice.percentage}%"></span>
              </div>
              <small>${slice.percentage}%</small>
            </div>
          `
        }).join("")}
      </div>
    `
  }

  function renderQueueDepthChart(chart) {
    if (!chart.queues.length) {
      return '<p class="empty-state">No queues currently have pending jobs.</p>'
    }

    return `
      <div class="queue-depth-list">
        ${chart.queues.map(function(queue) {
          return `
            <div class="queue-depth-row">
              <div class="queue-depth-label">
                <strong>${escapeHtml(queue.name)}</strong>
                <span>${queue.queued} queued</span>
              </div>
              <div class="queue-depth-track">
                <span class="queue-depth-fill" style="width:${heightPercent(queue.queued, chart.max)}%"></span>
              </div>
            </div>
          `
        }).join("")}
      </div>
    `
  }

  function renderBackend(backend) {
    return `
      <div class="backend-grid">
        <article class="backend-card">
          <p>Queue Adapter</p>
          <strong>${escapeHtml(backend.queue_adapter)}</strong>
        </article>
        <article class="backend-card">
          <p>Storage Backend</p>
          <strong>${escapeHtml(backend.storage_backend)}</strong>
        </article>
        <article class="backend-card">
          <p>Redis</p>
          <strong>${backend.redis.configured ? "Configured" : "Not Configured"}</strong>
        </article>
        <article class="backend-card">
          <p>Recurring Tasks</p>
          <strong>${backend.recurring_configured}</strong>
        </article>
      </div>
      <div class="backend-list">
        <h3>Database Connections</h3>
        <ul class="list compact">
          ${backend.databases.map(function(database) {
            return `
              <li>
                <strong>${escapeHtml(database.name)}</strong>
                <span>${escapeHtml(database.adapter)} · ${escapeHtml(database.database)}</span>
              </li>
            `
          }).join("")}
        </ul>
        ${backend.redis.url ? `<p class="backend-note">Redis URL: ${escapeHtml(backend.redis.url)}</p>` : ""}
      </div>
    `
  }

  function pulseBeacon() {
    const beacon = document.getElementById("backline-beacon")
    if (!beacon) return
    beacon.classList.remove("pulse")
    void beacon.offsetWidth
    beacon.classList.add("pulse")
  }

  document.addEventListener("DOMContentLoaded", function() {
    const root = document.querySelector("[data-backline-dashboard]")
    if (!root) return

    const url = root.dataset.backlineDashboardUrlValue
    const jobsPath = root.dataset.backlineDashboardJobsPathValue
    const batchesPath = root.dataset.backlineDashboardBatchesPathValue
    const workflowsPath = root.dataset.backlineDashboardWorkflowsPathValue
    const intervalSlider = root.querySelector('[data-backline-dashboard-target="intervalSlider"]')
    const intervalLabel = root.querySelector('[data-backline-dashboard-target="intervalLabel"]')
    const defaultInterval = parseInt(root.dataset.backlineDashboardIntervalValue || "5000", 10)
    let interval = parseInt(localStorage.backlineDashboardInterval || defaultInterval, 10)
    let timer = null

    if (Number.isNaN(interval) || interval < 2000) interval = 5000

    function formatIntervalLabel(value) {
      return Math.round(parseInt(value, 10) / 1000) + " s"
    }

    function syncIntervalUi(value) {
      if (intervalSlider) intervalSlider.value = value
      if (intervalLabel) intervalLabel.textContent = formatIntervalLabel(value)
    }

    syncIntervalUi(interval)

    function updateText(target, value) {
      root.querySelectorAll(`[data-backline-dashboard-target="${target}"]`).forEach(function(node) {
        node.textContent = value
      })
    }

    function renderSnapshot(snapshot) {
      updateText("generatedAt", formatTimestamp(snapshot.generated_at))
      updateText("summaryQueued", snapshot.summary.queued)
      updateText("summaryBusy", snapshot.summary.busy)
      updateText("summaryRetries", snapshot.summary.retries)
      updateText("summaryWorkers", snapshot.summary.workers)
      updateText("summaryWorkersHealthy", snapshot.summary.workers_healthy)
      updateText("summaryProcessedTotal", snapshot.summary.processed_total)
      updateText("summaryFailureTotal", snapshot.summary.failure_total)
      updateText("summaryScheduled", snapshot.summary.scheduled)
      updateText("summaryRunning", snapshot.summary.running)
      updateText("summaryFailed", snapshot.summary.failed)
      updateText("summaryDead", snapshot.summary.dead)
      updateText("summaryRateLimited", snapshot.summary.rate_limited)
      updateText("summarySucceededToday", snapshot.summary.succeeded_today)
      updateText("summaryActiveBatches", snapshot.summary.active_batches)
      updateText("summaryActiveWorkflows", snapshot.summary.active_workflows)

      const batches = root.querySelector('[data-backline-dashboard-target="batches"]')
      if (batches) {
        batches.innerHTML = snapshot.batches.length ? snapshot.batches.map(function(batch) {
          return `
            <li>
              <div class="list-row">
                <a href="${batchesPath}/${batch.id}">${escapeHtml(batch.name)}</a>
                <span class="pill pill-${batch.status}">${escapeHtml(batch.status)}</span>
              </div>
              <span>${batch.completed_jobs} complete, ${batch.failed_jobs} failed, ${batch.total_jobs} total</span>
              <div class="queue-depth-track">
                <span class="queue-depth-fill" style="width:${batch.progress_percentage}%"></span>
              </div>
            </li>
          `
        }).join("") : '<li><strong>No batches yet</strong><span>Batch activity will appear here once grouped jobs are enqueued.</span></li>'
      }

      const workflows = root.querySelector('[data-backline-dashboard-target="workflows"]')
      if (workflows) {
        workflows.innerHTML = snapshot.workflows.length ? snapshot.workflows.map(function(workflow) {
          return `
            <li>
              <div class="list-row">
                <a href="${workflowsPath}/${workflow.id}">${escapeHtml(workflow.name)}</a>
                <span class="pill pill-${workflow.status}">${escapeHtml(workflow.status)}</span>
              </div>
              <span>${workflow.completed_steps} completed of ${workflow.total_steps} steps</span>
              <div class="queue-depth-track">
                <span class="queue-depth-fill" style="width:${workflow.progress_percentage}%"></span>
              </div>
            </li>
          `
        }).join("") : '<li><strong>No workflows yet</strong><span>Chained work will appear here once workflows start running.</span></li>'
      }

      const throughput = root.querySelector('[data-backline-dashboard-target="throughput"]')
      if (throughput) {
        const throughputConfig = {
          series: [
            { key: "queued", label: "Queued", stroke: "#f0b35b", fill: "rgba(240, 179, 91, 0.12)" },
            { key: "succeeded", label: "Succeeded", stroke: "#1f8f54", fill: "rgba(31, 143, 84, 0.12)" },
            { key: "failed", label: "Failed", stroke: "#b33a32", fill: "rgba(179, 58, 50, 0.10)" }
          ]
        }

        if (!ensureChartJs(root, "throughput", snapshot.charts.throughput, throughputConfig)) {
          if (hasChartJs()) {
            updateChartJs("throughput", snapshot.charts.throughput, throughputConfig)
          } else {
            throughput.innerHTML = renderThroughputChart(snapshot.charts.throughput)
          }
        }
      }

      const history = root.querySelector('[data-backline-dashboard-target="history"]')
      if (history) {
        const historyConfig = {
          series: [
            { key: "processed", label: "Processed", stroke: "#1f8f54", fill: "rgba(31, 143, 84, 0.12)" },
            { key: "failed", label: "Failed", stroke: "#b33a32", fill: "rgba(179, 58, 50, 0.10)" }
          ]
        }

        if (!ensureChartJs(root, "history", snapshot.charts.history, historyConfig)) {
          if (hasChartJs()) {
            updateChartJs("history", snapshot.charts.history, historyConfig)
          } else {
            history.innerHTML = renderHistoryChart(snapshot.charts.history)
          }
        }
      }

      const status = root.querySelector('[data-backline-dashboard-target="statusDistribution"]')
      if (status) status.innerHTML = renderStatusChart(snapshot.charts.status_distribution)

      const queueDepth = root.querySelector('[data-backline-dashboard-target="queueDepth"]')
      if (queueDepth) queueDepth.innerHTML = renderQueueDepthChart(snapshot.charts.queue_depth)

      const backend = root.querySelector('[data-backline-dashboard-target="backend"]')
      if (backend) backend.innerHTML = renderBackend(snapshot.backend)

      pulseBeacon()
    }

    function poll() {
      fetch(url, { headers: { Accept: "application/json" } })
        .then(function(response) { return response.ok ? response.json() : null })
        .then(function(snapshot) { if (snapshot) renderSnapshot(snapshot) })
        .catch(function() {})
    }

    function startPolling() {
      if (timer) clearInterval(timer)
      poll()
      timer = setInterval(poll, interval)
    }

    if (intervalSlider) {
      intervalSlider.addEventListener("input", function(event) {
        if (intervalLabel) intervalLabel.textContent = formatIntervalLabel(event.target.value)
      })

      intervalSlider.addEventListener("change", function(event) {
        interval = parseInt(event.target.value, 10)
        localStorage.backlineDashboardInterval = String(interval)
        syncIntervalUi(interval)
        startPolling()
      })
    }

    startPolling()

    root.addEventListener("mouseenter", function(event) {
      const hotspot = event.target.closest(".line-chart-hotspot")
      if (!hotspot) return
      const chart = hotspot.closest("[data-line-chart]")
      const tooltip = chart && chart.querySelector("[data-line-chart-tooltip]")
      if (!tooltip) return

      tooltip.hidden = false
      tooltip.innerHTML = `<strong>${hotspot.dataset.label}</strong><span>${hotspot.dataset.values}</span>`
    }, true)

    root.addEventListener("mousemove", function(event) {
      const hotspot = event.target.closest(".line-chart-hotspot")
      if (!hotspot) return
      const chart = hotspot.closest("[data-line-chart]")
      const tooltip = chart && chart.querySelector("[data-line-chart-tooltip]")
      if (!tooltip) return

      const rect = chart.getBoundingClientRect()
      const left = ((event.clientX - rect.left) / rect.width) * 100
      const top = ((event.clientY - rect.top) / rect.height) * 100
      tooltip.style.left = `${Math.min(Math.max(left, 8), 92)}%`
      tooltip.style.top = `${Math.min(Math.max(top - 10, 8), 82)}%`
    })

    root.addEventListener("mouseleave", function(event) {
      const hotspot = event.target.closest(".line-chart-hotspot")
      if (!hotspot) return
      const chart = hotspot.closest("[data-line-chart]")
      const tooltip = chart && chart.querySelector("[data-line-chart-tooltip]")
      if (tooltip) tooltip.hidden = true
    }, true)
  })
})()
