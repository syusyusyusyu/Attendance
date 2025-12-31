import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "toggle"]

  toggleAll() {
    const checked = this.toggleTarget.checked
    this.itemTargets.forEach((item) => {
      item.checked = checked
    })
  }

  syncToggle() {
    const total = this.itemTargets.length
    const checked = this.itemTargets.filter((item) => item.checked).length
    if (this.hasToggleTarget) {
      this.toggleTarget.checked = total > 0 && checked === total
      this.toggleTarget.indeterminate = checked > 0 && checked < total
    }
  }
}
