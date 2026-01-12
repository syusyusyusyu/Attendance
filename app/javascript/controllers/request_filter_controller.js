import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { debounce: { type: Number, default: 250 } }

  submit() {
    if (typeof this.element?.requestSubmit !== "function") return
    this.element.requestSubmit()
  }

  submitDebounced(event) {
    if (event?.isComposing) return
    if (typeof this.element?.requestSubmit !== "function") return

    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      this.element.requestSubmit()
    }, this.debounceValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}

