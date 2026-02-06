import { Controller } from "@hotwired/stimulus"

const SIDEBAR_WIDTH = 240 // --sidebar-width: 15rem = 240px
const EDGE_ZONE = 20      // 画面左端からのスワイプ検出範囲(px)
const THRESHOLD_RATIO = 0.3 // 開閉確定の閾値（サイドバー幅の30%）
const DIRECTION_LOCK_DISTANCE = 10 // 縦横判定のための最小移動距離(px)

export default class extends Controller {
  static targets = ["sidebar", "overlay"]

  connect() {
    document.body.classList.remove("sidebar-open")

    this._onTouchStart = this._onTouchStart.bind(this)
    this._onTouchMove = this._onTouchMove.bind(this)
    this._onTouchEnd = this._onTouchEnd.bind(this)
    document.addEventListener("touchstart", this._onTouchStart, { passive: true })
    document.addEventListener("touchmove", this._onTouchMove, { passive: false })
    document.addEventListener("touchend", this._onTouchEnd, { passive: true })
  }

  disconnect() {
    document.body.classList.remove("sidebar-open")

    document.removeEventListener("touchstart", this._onTouchStart)
    document.removeEventListener("touchmove", this._onTouchMove)
    document.removeEventListener("touchend", this._onTouchEnd)
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

  // --- Touch gesture handling ---

  _isDesktop() {
    return window.matchMedia("(min-width: 1024px)").matches
  }

  _isSidebarOpen() {
    return this.hasSidebarTarget && !this.sidebarTarget.classList.contains("-translate-x-full")
  }

  _onTouchStart(e) {
    if (this._isDesktop()) return
    if (!this.hasSidebarTarget || !this.hasOverlayTarget) return

    const touch = e.touches[0]
    this._startX = touch.clientX
    this._startY = touch.clientY
    this._tracking = false
    this._directionLocked = false
    this._isVertical = false

    const isOpen = this._isSidebarOpen()
    this._edgeSwipe = !isOpen && touch.clientX <= EDGE_ZONE
    this._closeSwipe = isOpen

    // どちらの操作にも該当しない場合は何もしない
    if (!this._edgeSwipe && !this._closeSwipe) {
      this._startX = null
      return
    }
  }

  _onTouchMove(e) {
    if (this._startX === null || this._startX === undefined) return
    if (this._isVertical) return

    const touch = e.touches[0]
    const deltaX = touch.clientX - this._startX
    const deltaY = touch.clientY - this._startY
    const absDeltaX = Math.abs(deltaX)
    const absDeltaY = Math.abs(deltaY)

    // 方向ロック: 最初の一定距離移動で縦横を判定
    if (!this._directionLocked) {
      if (absDeltaX < DIRECTION_LOCK_DISTANCE && absDeltaY < DIRECTION_LOCK_DISTANCE) {
        return // まだ判定不能
      }
      this._directionLocked = true
      if (absDeltaY > absDeltaX) {
        // 縦方向優勢 → スクロールを優先、タッチ追跡中止
        this._isVertical = true
        return
      }
    }

    // 横方向のスワイプ確定 → スクロール防止
    e.preventDefault()

    if (!this._tracking) {
      // ドラッグ開始: transition を無効化してリアルタイム追従
      this._tracking = true
      this.sidebarTarget.style.transition = "none"
      if (this._edgeSwipe) {
        // エッジスワイプ開始時: サイドバーを画面外に配置、overlayを表示（透明）
        this.sidebarTarget.classList.remove("-translate-x-full")
        this.sidebarTarget.style.transform = `translateX(${-SIDEBAR_WIDTH}px)`
        this.overlayTarget.classList.remove("hidden")
        this.overlayTarget.style.opacity = "0"
      }
    }

    if (this._closeSwipe) {
      // 開いている状態 → 左スワイプで閉じる方向に追従
      const offset = Math.min(0, Math.max(-SIDEBAR_WIDTH, deltaX))
      this.sidebarTarget.style.transform = `translateX(${offset}px)`
      // オーバーレイ透明度追従
      const progress = 1 - Math.abs(offset) / SIDEBAR_WIDTH
      this.overlayTarget.style.opacity = String(0.3 * progress)
    } else if (this._edgeSwipe) {
      // 閉じている状態 → 右スワイプで開く方向に追従
      const clampedDelta = Math.max(0, Math.min(SIDEBAR_WIDTH, deltaX))
      const offset = -SIDEBAR_WIDTH + clampedDelta
      this.sidebarTarget.style.transform = `translateX(${offset}px)`
      // オーバーレイ透明度追従
      const progress = clampedDelta / SIDEBAR_WIDTH
      this.overlayTarget.style.opacity = String(0.3 * progress)
    }
  }

  _onTouchEnd(_e) {
    if (this._startX === null || this._startX === undefined) return
    if (!this._tracking) {
      this._resetTouchState()
      return
    }

    // インラインスタイルをリセット（CSSのtransitionに戻す）
    this.sidebarTarget.style.transition = ""
    this.sidebarTarget.style.transform = ""
    this.overlayTarget.style.opacity = ""

    const touch = _e.changedTouches[0]
    const deltaX = touch.clientX - this._startX
    const threshold = SIDEBAR_WIDTH * THRESHOLD_RATIO

    if (this._closeSwipe) {
      // 左方向に閾値以上ドラッグ → 閉じる
      if (deltaX < -threshold) {
        this.close()
      }
      // 閾値未満 → そのまま（open状態を維持、CSSが元に戻す）
    } else if (this._edgeSwipe) {
      // 右方向に閾値以上ドラッグ → 開く
      if (deltaX > threshold) {
        this.open()
      } else {
        // 閾値未満 → 閉じた状態に戻す
        this.close()
      }
    }

    this._resetTouchState()
  }

  _resetTouchState() {
    this._startX = null
    this._startY = null
    this._tracking = false
    this._directionLocked = false
    this._isVertical = false
    this._edgeSwipe = false
    this._closeSwipe = false
  }
}
