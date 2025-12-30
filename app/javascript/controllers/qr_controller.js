import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["code", "timeLeft"]
  static values = { expiresAt: Number, filename: String }

  connect() {
    if (!this.hasExpiresAtValue) return

    this.updateTimeLeft()
    this.timer = setInterval(() => this.updateTimeLeft(), 1000)
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
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

  download() {
    if (!this.hasCodeTarget) return

    const svg = this.codeTarget.querySelector("svg")
    if (!svg) return

    const serializer = new XMLSerializer()
    let source = serializer.serializeToString(svg)

    if (!source.includes("xmlns=\"http://www.w3.org/2000/svg\"")) {
      source = source.replace("<svg", '<svg xmlns="http://www.w3.org/2000/svg"')
    }

    const blob = new Blob([source], { type: "image/svg+xml;charset=utf-8" })
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = url
    link.download = this.hasFilenameValue ? this.filenameValue : "qrcode.svg"
    document.body.appendChild(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(url)
  }
}
