import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "timeLeft"]
  static values = { expiresAt: Number, filename: String, refreshUrl: String, refreshInterval: Number }

  connect() {
    if (this.hasExpiresAtValue) {
      this.updateTimeLeft()
      this.timer = setInterval(() => this.updateTimeLeft(), 1000)
    }

    if (this.hasRefreshUrlValue) {
      const interval = this.hasRefreshIntervalValue ? this.refreshIntervalValue : 10
      this.refreshTimer = setInterval(() => this.refresh(), interval * 1000)
    }
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
    }

    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }

  updateTimeLeft() {
    if (!this.hasExpiresAtValue || !this.hasTimeLeftTarget) return

    const now = Math.floor(Date.now() / 1000)
    const remaining = Math.max(this.expiresAtValue - now, 0)
    const minutes = Math.floor(remaining / 60)
    const seconds = remaining % 60
    this.timeLeftTarget.textContent = `${minutes}:${seconds.toString().padStart(2, "0")}`
  }

  async refresh() {
    if (!this.hasRefreshUrlValue || !this.hasImageTarget) return

    try {
      const response = await fetch(this.refreshUrlValue, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) return

      const data = await response.json()
      if (data.png_data_url) {
        this.imageTarget.src = data.png_data_url
      }
      if (data.expires_at) {
        this.expiresAtValue = data.expires_at
        this.updateTimeLeft()
      }
    } catch (_error) {
      // ignore refresh errors
    }
  }

  download() {
    if (!this.hasImageTarget) return

    const url = this.imageTarget.src
    if (!url) return

    const link = document.createElement("a")
    link.href = url
    link.download = this.hasFilenameValue ? this.filenameValue : "qrcode.png"
    document.body.appendChild(link)
    link.click()
    link.remove()
  }
}
