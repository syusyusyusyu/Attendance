import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]

  connect() {
    const theme = localStorage.getItem("theme") || document.documentElement.getAttribute("data-theme") || "light"
    this.applyTheme(theme)
    if (this.hasCheckboxTarget) {
      this.checkboxTarget.checked = theme === "dark"
    }
  }

  toggle() {
    const newTheme = this.checkboxTarget.checked ? "dark" : "light"
    this.applyTheme(newTheme)
    this.saveToServer(newTheme)
  }

  applyTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme)
    localStorage.setItem("theme", theme)

    const meta = document.querySelector('meta[name="theme-color"]')
    if (meta) {
      meta.setAttribute("content", theme === "dark" ? "#1A1A26" : "#5B5BD6")
    }
  }

  saveToServer(theme) {
    const csrfMeta = document.querySelector("meta[name='csrf-token']")
    const token = csrfMeta ? csrfMeta.getAttribute("content") : ""

    fetch("/profile/update_theme", {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token
      },
      body: JSON.stringify({ theme: theme })
    })
  }
}
