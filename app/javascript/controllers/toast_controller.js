import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: { type: Number, default: 4500 } }

  connect() {
    this.element.classList.remove("opacity-0", "translate-y-2")

    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      this.close()
    }, this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
    clearTimeout(this.removeTimer)
  }

  close() {
    clearTimeout(this.timer)
    this.element.classList.add("opacity-0", "translate-y-2")
    clearTimeout(this.removeTimer)
    this.removeTimer = setTimeout(() => {
      this.element.remove()
    }, 220)
  }
}

