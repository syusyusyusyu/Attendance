import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "row", "select"]
  static values = { storageKey: String }

  connect() {
    this.restore()
    this.filter()
  }

  filter() {
    const term = this.hasInputTarget ? this.inputTarget.value.trim().toLowerCase() : ""
    const role = this.hasSelectTarget ? this.selectTarget.value : ""

    this.rowTargets.forEach((row) => {
      const text = row.textContent.toLowerCase()
      const rowRole = row.dataset.role || ""
      const matchTerm = !term || text.includes(term)
      const matchRole = !role || rowRole === role
      row.classList.toggle("hidden", !(matchTerm && matchRole))
    })

    this.persist(term, role)
  }

  persist(term, role) {
    if (!this.hasStorageKeyValue || !window.localStorage) return
    const payload = { term: term, role: role }
    window.localStorage.setItem(this.storageKeyValue, JSON.stringify(payload))
  }

  restore() {
    if (!this.hasStorageKeyValue || !window.localStorage) return
    const raw = window.localStorage.getItem(this.storageKeyValue)
    if (!raw) return
    try {
      const payload = JSON.parse(raw)
      if (this.hasInputTarget && typeof payload.term === "string") {
        this.inputTarget.value = payload.term
      }
      if (this.hasSelectTarget && typeof payload.role === "string") {
        this.selectTarget.value = payload.role
      }
    } catch (_error) {
      window.localStorage.removeItem(this.storageKeyValue)
    }
  }
}
