import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { open: { type: Boolean, default: false } }

  connect() {
    this.isOpen = false
    if (this.openValue) {
      this.open()
    }
  }

  disconnect() {
    clearTimeout(this.openTimer)
    clearTimeout(this.closeTimer)
  }

  open() {
    if (this.isOpen) return
    this.isOpen = true
    this.element.classList.remove("hidden")
    this.animateOpen()
  }

  close() {
    if (!this.isOpen) {
      this.element.classList.add("hidden")
      return
    }
    this.animateClose()
  }

  animateOpen() {
    const el = this.element
    el.style.overflow = "hidden"
    el.style.maxHeight = "0px"
    el.style.opacity = "0"
    el.style.transform = "translateY(-6px)"
    el.style.transition = "max-height 220ms ease, opacity 200ms ease, transform 200ms ease"

    requestAnimationFrame(() => {
      const height = el.scrollHeight
      el.style.maxHeight = `${height}px`
      el.style.opacity = "1"
      el.style.transform = "translateY(0)"
    })

    clearTimeout(this.openTimer)
    this.openTimer = setTimeout(() => {
      el.style.maxHeight = "none"
      el.style.overflow = "visible"
    }, 240)
  }

  animateClose() {
    const el = this.element
    el.style.overflow = "hidden"
    el.style.maxHeight = `${el.scrollHeight}px`
    el.style.opacity = "1"
    el.style.transform = "translateY(0)"
    el.style.transition = "max-height 220ms ease, opacity 200ms ease, transform 200ms ease"

    requestAnimationFrame(() => {
      el.style.maxHeight = "0px"
      el.style.opacity = "0"
      el.style.transform = "translateY(-6px)"
    })

    clearTimeout(this.closeTimer)
    this.closeTimer = setTimeout(() => {
      el.classList.add("hidden")
      el.style.maxHeight = ""
      el.style.opacity = ""
      el.style.transform = ""
      el.style.transition = ""
      el.style.overflow = ""
      this.isOpen = false
    }, 240)
  }
}
