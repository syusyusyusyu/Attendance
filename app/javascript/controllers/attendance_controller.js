import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "search",
    "row",
    "statusSelect",
    "statusBadge",
    "editButton",
    "saveButton",
    "cancelButton"
  ]
  static values = { editing: Boolean }

  connect() {
    this.updateState()
  }

  edit() {
    this.editingValue = true
    this.updateState()
  }

  cancel() {
    this.editingValue = false
    this.resetSelects()
    this.updateState()
  }

  filter() {
    const term = this.searchTarget.value.trim().toLowerCase()

    this.rowTargets.forEach((row) => {
      const name = (row.dataset.name || "").toLowerCase()
      const studentId = (row.dataset.studentId || "").toLowerCase()
      const match = !term || name.includes(term) || studentId.includes(term)
      row.classList.toggle("hidden", !match)
    })
  }

  updateState() {
    const editing = this.editingValue

    this.statusSelectTargets.forEach((field) => {
      field.classList.toggle("hidden", !editing)
    })
    this.statusBadgeTargets.forEach((badge) => {
      badge.classList.toggle("hidden", editing)
    })

    if (this.hasEditButtonTarget) {
      this.editButtonTarget.classList.toggle("hidden", editing)
    }
    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.classList.toggle("hidden", !editing)
    }
    if (this.hasCancelButtonTarget) {
      this.cancelButtonTarget.classList.toggle("hidden", !editing)
    }
  }

  resetSelects() {
    this.statusSelectTargets.forEach((field) => {
      if (field.dataset.initialValue) {
        field.value = field.dataset.initialValue
      }
    })
  }
}
