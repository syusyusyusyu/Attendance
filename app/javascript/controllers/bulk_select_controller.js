import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "toggle", "floating", "count"]
  static values = { formId: String }

  connect() {
    this.pendingRows = []

    this.handleKeydown = this.handleKeydown.bind(this)
    window.addEventListener("keydown", this.handleKeydown)

    this.handleBeforeStreamRender = this.handleBeforeStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.handleBeforeStreamRender)

    this.form = this.hasFormIdValue ? document.getElementById(this.formIdValue) : null
    if (this.form) {
      this.handleSubmitStart = this.handleSubmitStart.bind(this)
      this.handleSubmitEnd = this.handleSubmitEnd.bind(this)
      this.form.addEventListener("turbo:submit-start", this.handleSubmitStart)
      this.form.addEventListener("turbo:submit-end", this.handleSubmitEnd)
    }

    this.syncToggle()
    this.updateFloating()
  }

  disconnect() {
    window.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("turbo:before-stream-render", this.handleBeforeStreamRender)
    if (this.form) {
      this.form.removeEventListener("turbo:submit-start", this.handleSubmitStart)
      this.form.removeEventListener("turbo:submit-end", this.handleSubmitEnd)
    }
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

  handleBeforeStreamRender(event) {
    const originalRender = event.detail.render
    event.detail.render = (streamElement) => {
      originalRender(streamElement)
      this.syncToggle()
    }
  }

  handleSubmitStart() {
    this.pendingRows = this.itemTargets
      .filter((item) => item.checked && !item.disabled)
      .map((item) => item.closest("tr"))
      .filter(Boolean)

    this.pendingRows.forEach((row) => row.classList.add("opacity-60"))
    if (this.hasFloatingTarget) {
      this.floatingTarget.classList.add("opacity-70", "pointer-events-none")
    }
  }

  handleSubmitEnd(event) {
    if (this.hasFloatingTarget) {
      this.floatingTarget.classList.remove("opacity-70", "pointer-events-none")
    }

    if (event.detail.success) {
      this.pendingRows = []
      this.updateFloating()
      return
    }

    this.pendingRows.forEach((row) => row.classList.remove("opacity-60"))
    this.pendingRows = []
    this.updateFloating()
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
