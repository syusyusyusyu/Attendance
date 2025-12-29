import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "editButton", "saveButton", "cancelButton"]
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
    this.updateState()
  }

  updateState() {
    const editing = this.editingValue

    this.fieldTargets.forEach((field) => {
      field.disabled = !editing
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
}
