import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]
  static values = { interval: { type: Number, default: 3000 } }

  connect() {
    this.timer = null
    if (this.poll()) {
      this.timer = window.setInterval(() => this.poll(), this.intervalValue)
    }
  }

  disconnect() {
    if (this.timer) window.clearInterval(this.timer)
  }

  poll() {
    const rows = this.rowTargets.filter((row) => row.dataset.processing === "true")
    if (!rows.length) {
      if (this.timer) window.clearInterval(this.timer)
      this.timer = null
      return false
    }

    rows.forEach((row) => this.refreshRow(row))
    return true
  }

  refreshRow(row) {
    fetch(row.dataset.statusUrl, { headers: { "Accept": "application/json" } })
      .then((response) => response.json())
      .then((data) => this.applyStatus(row, data))
      .catch(() => {})
  }

  applyStatus(row, data) {
    row.dataset.processing = data.processing ? "true" : "false"

    const badge = row.querySelector("[data-status-badge]")
    if (badge) {
      badge.className = `badge badge-${data.badge_class}`
      badge.textContent = data.human_status
    }

    const error = row.querySelector("[data-error-summary]")
    if (error) {
      error.textContent = data.error_summary || ""
      error.hidden = !data.error_summary
      error.dataset.errorMessage = data.error_message || ""
    }

    const slot = row.querySelector("[data-primary-action-slot]")
    if (slot && !data.processing) {
      slot.replaceChildren()
      if (data.presentable && data.present_url) {
        slot.append(this.linkButton(data.present_url, "▶", "Trình chiếu", "btn btn-primary btn-icon btn-sm", true))
      } else if (data.retry_url) {
        slot.append(this.retryForm(data.retry_url))
      } else {
        slot.append(this.muted("..."))
      }
    }
  }

  linkButton(url, icon, label, className, newTab = false) {
    const link = document.createElement("a")
    link.href = url
    link.className = className
    link.title = label
    link.setAttribute("aria-label", label)
    link.textContent = icon
    if (newTab) {
      link.target = "_blank"
      link.rel = "noopener"
    }
    return link
  }

  retryForm(url) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = url
    form.className = "button_to"
    form.append(this.hidden("authenticity_token", this.csrfToken()))

    const button = document.createElement("button")
    button.type = "submit"
    button.className = "btn btn-secondary btn-icon btn-sm"
    button.title = "Convert lại"
    button.setAttribute("aria-label", "Convert lại")
    button.textContent = "↻"
    form.append(button)
    return form
  }

  hidden(name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    return input
  }

  muted(text) {
    const span = document.createElement("span")
    span.className = "text-muted"
    span.textContent = text
    return span
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']").content
  }
}
