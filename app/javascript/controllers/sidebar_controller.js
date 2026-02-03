import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay"]

  connect() {
    document.body.classList.remove("sidebar-open")
  }

  disconnect() {
    document.body.classList.remove("sidebar-open")
  }

  toggle() {
    if (!this.hasSidebarTarget || !this.hasOverlayTarget) return

    if (this.sidebarTarget.classList.contains("-translate-x-full")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    if (!this.hasSidebarTarget || !this.hasOverlayTarget) return

    this.sidebarTarget.classList.remove("-translate-x-full")
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("sidebar-open")
  }

  close() {
    if (!this.hasSidebarTarget || !this.hasOverlayTarget) return

    this.sidebarTarget.classList.add("-translate-x-full")
    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("sidebar-open")
  }
}
