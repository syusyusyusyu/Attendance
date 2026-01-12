import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "toggle", "floating", "count"]
  static values = { formId: String }

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    window.addEventListener("keydown", this.handleKeydown)
    this.syncToggle()
    this.updateFloating()
  }

  disconnect() {
    window.removeEventListener("keydown", this.handleKeydown)
  }

  toggleAll() {
    const checked = this.toggleTarget.checked
    this.itemTargets.forEach((item) => {
      if (item.disabled) return
      item.checked = checked
    })
    this.updateFloating()
  }

  syncToggle() {
    const total = this.itemTargets.length
    const checked = this.itemTargets.filter((item) => item.checked).length
    if (this.hasToggleTarget) {
      this.toggleTarget.checked = total > 0 && checked === total
      this.toggleTarget.indeterminate = checked > 0 && checked < total
    }
    this.updateFloating()
  }

  handleKeydown(event) {
    if (!this.hasFormIdValue || this.isTyping(event)) {
      return
    }

    if (event.shiftKey && event.key.toLowerCase() === "a") {
      event.preventDefault()
      this.submitBulk("approved")
    }

    if (event.shiftKey && event.key.toLowerCase() === "r") {
      event.preventDefault()
      this.submitBulk("rejected")
    }
  }

  submitBulk(status) {
    const selected = this.itemTargets.filter((item) => item.checked && !item.disabled)
    if (selected.length === 0) {
      window.alert("処理対象の申請を選択してください。")
      return
    }

    const form = document.getElementById(this.formIdValue)
    if (!form) {
      return
    }

    const submitter = form.querySelector(`button[name="status"][value="${status}"]`)
    if (submitter) {
      submitter.click()
    } else {
      form.requestSubmit()
    }
  }

  approveSelected() {
    this.submitBulk("approved")
  }

  rejectSelected() {
    this.submitBulk("rejected")
  }

  isTyping(event) {
    const target = event.target
    if (!target) {
      return false
    }
    const tagName = target.tagName?.toLowerCase()
    return tagName === "input" || tagName === "textarea" || tagName === "select" || target.isContentEditable
  }

  updateFloating() {
    if (!this.hasFloatingTarget || !this.hasCountTarget) return
    const selected = this.itemTargets.filter((item) => item.checked && !item.disabled)
    this.countTarget.textContent = selected.length.toString()
    this.floatingTarget.classList.toggle("hidden", selected.length === 0)
  }
}
