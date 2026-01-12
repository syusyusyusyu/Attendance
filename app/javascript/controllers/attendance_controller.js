import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "search",
    "statusFilter",
    "row",
    "statusSelect",
    "statusBadge",
    "editButton",
    "saveButton",
    "cancelButton",
    "reasonBlock"
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
    const statusValue = this.hasStatusFilterTarget ? this.statusFilterTarget.value : ""

    this.rowTargets.forEach((row) => {
      const name = (row.dataset.name || "").toLowerCase()
      const studentId = (row.dataset.studentId || "").toLowerCase()
      const rowStatus = row.dataset.status || ""
      const requestStatus = row.dataset.request || ""
      const matchTerm = !term || name.includes(term) || studentId.includes(term)
      let matchStatus = true

      if (statusValue) {
        if (statusValue === "pending_request") {
          matchStatus = requestStatus === "pending"
        } else if (statusValue === "missing") {
          matchStatus = rowStatus === "missing"
        } else {
          matchStatus = rowStatus === statusValue
        }
      }

      row.classList.toggle("hidden", !(matchTerm && matchStatus))
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
    if (this.hasReasonBlockTarget) {
      const drawer = this.drawerFor(this.reasonBlockTarget)
      if (drawer) {
        if (editing) {
          drawer.open()
        } else {
          drawer.close()
        }
      } else {
        this.reasonBlockTarget.classList.toggle("hidden", !editing)
      }
    }
  }

  resetSelects() {
    this.statusSelectTargets.forEach((field) => {
      if (field.dataset.initialValue) {
        field.value = field.dataset.initialValue
      }
    })
    this.rowTargets.forEach((row) => {
      row.classList.remove("bg-yellow-50")
    })
  }

  markChanged(event) {
    const field = event.target
    const row = field.closest("tr")
    if (!row) return

    const changed = field.value !== field.dataset.initialValue
    row.classList.toggle("bg-yellow-50", changed)
  }

  submitEnd(event) {
    if (!event.detail.success) return

    this.editingValue = false
    this.resetSelects()
    this.updateState()
  }

  drawerFor(element) {
    return this.application.getControllerForElementAndIdentifier(element, "drawer")
  }
}
