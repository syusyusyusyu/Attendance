import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { open: { type: Boolean, default: false } }
  static openCount = 0

  connect() {
    this.isOpen = false
    this.handleFrameLoad = this.handleFrameLoad.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
    this.element.addEventListener("turbo:frame-load", this.handleFrameLoad)

    // アクセシビリティ属性を設定
    this.element.setAttribute("role", "dialog")
    this.element.setAttribute("aria-modal", "true")

    if (this.openValue) {
      this.open()
    }
  }

  disconnect() {
    clearTimeout(this.openTimer)
    clearTimeout(this.closeTimer)
    if (this.isOpen) {
      this.unlockScroll()
      this.removeKeyboardListener()
      this.isOpen = false
    }
    this.element.removeEventListener("turbo:frame-load", this.handleFrameLoad)
  }

  open() {
    if (this.isOpen) return
    this.isOpen = true
    this.lockScroll()
    this.addKeyboardListener()
    this.element.classList.remove("hidden")
    this.animateOpen()

    // フォーカスをドロワー内に移動
    requestAnimationFrame(() => {
      this.trapFocus()
    })
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
      this.unlockScroll()
      this.removeKeyboardListener()
      this.restoreFocus()
    }, 240)
  }

  handleFrameLoad() {
    if (this.element.classList.contains("hidden")) {
      this.open()
    }
  }

  // ESCキーでドロワーを閉じる
  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }

    // Tab キーでフォーカストラップ
    if (event.key === "Tab") {
      this.handleTabKey(event)
    }
  }

  // フォーカストラップ処理
  handleTabKey(event) {
    const focusableElements = this.getFocusableElements()
    if (focusableElements.length === 0) return

    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]

    if (event.shiftKey) {
      // Shift+Tab: 最初の要素から最後の要素へ
      if (document.activeElement === firstElement) {
        event.preventDefault()
        lastElement.focus()
      }
    } else {
      // Tab: 最後の要素から最初の要素へ
      if (document.activeElement === lastElement) {
        event.preventDefault()
        firstElement.focus()
      }
    }
  }

  // フォーカス可能な要素を取得
  getFocusableElements() {
    const selector = [
      'button:not([disabled])',
      'a[href]',
      'input:not([disabled])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      '[tabindex]:not([tabindex="-1"])'
    ].join(', ')

    return Array.from(this.element.querySelectorAll(selector))
      .filter(el => el.offsetParent !== null)
  }

  // フォーカスをドロワー内にトラップ
  trapFocus() {
    this.previousActiveElement = document.activeElement
    const focusableElements = this.getFocusableElements()

    if (focusableElements.length > 0) {
      focusableElements[0].focus()
    } else {
      this.element.focus()
    }
  }

  // フォーカスを元の要素に戻す
  restoreFocus() {
    if (this.previousActiveElement && this.previousActiveElement.focus) {
      this.previousActiveElement.focus()
    }
  }

  addKeyboardListener() {
    document.addEventListener("keydown", this.handleKeydown)
  }

  removeKeyboardListener() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  lockScroll() {
    if (DrawerController.openCount === 0) {
      document.body.classList.add("drawer-open")
    }
    DrawerController.openCount += 1
  }

  unlockScroll() {
    DrawerController.openCount = Math.max(0, DrawerController.openCount - 1)
    if (DrawerController.openCount === 0) {
      document.body.classList.remove("drawer-open")
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
