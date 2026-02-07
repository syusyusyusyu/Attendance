import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["counter", "progressBar"]

  toggle(event) {
    const checkbox = event.target
    const card = checkbox.closest(".card")
    const toggle = checkbox.nextElementSibling

    if (checkbox.checked) {
      toggle.style.background = "var(--color-success)"
    } else {
      toggle.style.background = "var(--color-bg-hover)"
    }

    this.updateProgress()
  }

  updateProgress() {
    if (!this.hasCounterTarget || !this.hasProgressBarTarget) return

    const checkboxes = this.element.querySelectorAll('input[name="student_ids[]"]')
    const checked = this.element.querySelectorAll('input[name="student_ids[]"]:checked').length
    const qrConfirmed = document.querySelectorAll("[data-roll-call-qr]").length
    const total = parseInt(this.counterTarget.textContent.split("/")[1]) || 0
    const confirmed = checked + qrConfirmed

    this.counterTarget.textContent = `${confirmed} / ${total} 人`
    const percent = total > 0 ? Math.round((confirmed / total) * 100) : 0
    this.progressBarTarget.style.width = `${percent}%`
  }
}
