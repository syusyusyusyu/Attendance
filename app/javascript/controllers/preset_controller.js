import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  fill(event) {
    const value = event?.params?.value
    if (!value || !this.hasInputTarget) return

    this.inputTarget.value = value
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.focus()
  }
}

