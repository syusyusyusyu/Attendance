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
    "reasonBlock",
    "changeBanner",
    "changeCount",
    "changeList"
  ]
  static values = { editing: Boolean }

  connect() {
    this.initializeRowOrder()
    this.updateState()
    this.updateChangeSummary()
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
      row.dataset.changed = ""
    })
    this.updateChangeSummary()
  }

  markChanged(event) {
    const field = event.target
    const row = field.closest("tr")
    if (!row) return

    const changed = field.value !== field.dataset.initialValue
    row.classList.toggle("bg-yellow-50", changed)
    row.dataset.changed = changed ? "true" : ""
    this.updateChangeSummary()
  }

  validateSubmit(event) {
    if (!this.editingValue) return

    const changedRows = this.rowTargets.filter((row) => row.dataset.changed === "true")
    if (changedRows.length === 0) return

    const reasonField = this.reasonBlockTarget?.querySelector("textarea")
    if (reasonField && reasonField.value.trim() === "") {
      event.preventDefault()
      reasonField.focus()
      reasonField.style.borderColor = "var(--color-error)"
      reasonField.setAttribute("placeholder", "修正理由を入力してください（必須）")
    }
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

  updateChangeSummary() {
    if (!this.hasChangeBannerTarget || !this.hasChangeCountTarget || !this.hasChangeListTarget) {
      return
    }

    this.ensureRowOrder()
    const changedRows = this.rowTargets.filter((row) => row.dataset.changed === "true")
    const count = changedRows.length
    this.changeCountTarget.textContent = count.toString()

    if (count === 0) {
      this.changeBannerTarget.classList.add("hidden")
      this.changeListTarget.textContent = ""
      this.reorderRows()
      return
    }

    const names = changedRows.map((row) => row.dataset.name || "").filter((name) => name.length > 0)
    const sample = names.slice(0, 3)
    const extra = names.length - sample.length
    const label = extra > 0 ? `${sample.join("、")} 他${extra}件` : sample.join("、")
    this.changeListTarget.textContent = label
    this.changeBannerTarget.classList.remove("hidden")
    this.reorderRows()
  }

  initializeRowOrder() {
    this.rowTargets.forEach((row, index) => {
      if (!row.dataset.order) {
        row.dataset.order = index.toString()
      }
    })
  }

  ensureRowOrder() {
    let updated = false
    this.rowTargets.forEach((row, index) => {
      if (!row.dataset.order) {
        row.dataset.order = index.toString()
        updated = true
      }
    })
    if (updated) {
      this.rowTargets.forEach((row, index) => {
        row.dataset.order ||= index.toString()
      })
    }
  }

  reorderRows() {
    const rows = [...this.rowTargets]
    const parent = rows[0]?.parentElement
    if (!parent) return

    rows.sort((a, b) => {
      const aChanged = a.dataset.changed === "true" ? 0 : 1
      const bChanged = b.dataset.changed === "true" ? 0 : 1
      if (aChanged !== bChanged) return aChanged - bChanged
      return Number(a.dataset.order) - Number(b.dataset.order)
    })

    rows.forEach((row) => parent.appendChild(row))
  }
}
