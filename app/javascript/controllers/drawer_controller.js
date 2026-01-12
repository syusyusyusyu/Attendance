import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { open: { type: Boolean, default: false } }

  connect() {
    this.isOpen = false
    this.handleFrameLoad = this.handleFrameLoad.bind(this)
    this.element.addEventListener("turbo:frame-load", this.handleFrameLoad)
    if (this.openValue) {
      this.open()
    }
  }

  disconnect() {
    clearTimeout(this.openTimer)
    clearTimeout(this.closeTimer)
    this.element.removeEventListener("turbo:frame-load", this.handleFrameLoad)
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
    const useSheet = this.useSheetLayout()
    const offset = useSheet ? 16 : -6
    const maxHeight = useSheet ? this.sheetMaxHeight(el) : el.scrollHeight
    el.style.overflow = "hidden"
    el.style.maxHeight = "0px"
    el.style.opacity = "0"
    el.style.transform = `translateY(${offset}px)`
    el.style.transition = "max-height 220ms ease, opacity 200ms ease, transform 200ms ease"

    requestAnimationFrame(() => {
      el.style.maxHeight = `${maxHeight}px`
      el.style.opacity = "1"
      el.style.transform = "translateY(0)"
    })

    clearTimeout(this.openTimer)
    this.openTimer = setTimeout(() => {
      if (useSheet) {
        el.style.maxHeight = `${maxHeight}px`
        el.style.overflow = "auto"
      } else {
        el.style.maxHeight = "none"
        el.style.overflow = "visible"
      }
    }, 240)
  }

  animateClose() {
    const el = this.element
    const useSheet = this.useSheetLayout()
    const offset = useSheet ? 16 : -6
    const maxHeight = useSheet ? this.sheetMaxHeight(el) : el.scrollHeight
    el.style.overflow = "hidden"
    el.style.maxHeight = `${maxHeight}px`
    el.style.opacity = "1"
    el.style.transform = "translateY(0)"
    el.style.transition = "max-height 220ms ease, opacity 200ms ease, transform 200ms ease"

    requestAnimationFrame(() => {
      el.style.maxHeight = "0px"
      el.style.opacity = "0"
      el.style.transform = `translateY(${offset}px)`
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

  handleFrameLoad() {
    if (this.element.classList.contains("hidden")) {
      this.open()
    }
  }

  useSheetLayout() {
    return this.element.classList.contains("drawer-sheet") &&
      window.matchMedia("(max-width: 640px)").matches
  }

  sheetMaxHeight(element) {
    const cap = Math.floor(window.innerHeight * 0.85)
    return Math.min(element.scrollHeight, cap)
  }
}
