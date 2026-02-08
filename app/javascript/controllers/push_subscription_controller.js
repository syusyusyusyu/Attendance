import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "subscribeButton", "unsubscribeButton", "testButton", "badge"]
  static values = { publicKey: String }

  connect() {
    this.supported = "serviceWorker" in navigator && "PushManager" in window
    this.updateUI()
    if (!this.supported) {
      this.showStatus("このブラウザではPush通知を利用できません。", "error")
      return
    }
    if (!this.publicKeyValue) {
      return
    }

    this.refreshSubscription()
  }

  async refreshSubscription() {
    const registration = await navigator.serviceWorker.getRegistration()
    this.subscription = registration ? await registration.pushManager.getSubscription() : null
    this.updateUI()
  }

  async subscribe() {
    if (!this.supported || !this.publicKeyValue) return
    if (!confirm("Push通知を有効化しますか？\nブラウザから通知の許可を求められます。")) return

    this.setLoading(this.subscribeButtonTarget, true)
    try {
      const registration = await navigator.serviceWorker.register("/service-worker.js")
      let subscription = await registration.pushManager.getSubscription()
      if (!subscription) {
        subscription = await registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: this.decodeKey(this.publicKeyValue)
        })
      }

      await this.saveSubscription(subscription)
      this.subscription = subscription
      this.showStatus("Push通知を有効化しました。", "success")
      this.updateUI()
    } catch (e) {
      this.showStatus(`有効化に失敗しました: ${e.message}`, "error")
    } finally {
      this.setLoading(this.subscribeButtonTarget, false)
    }
  }

  async unsubscribe() {
    if (!this.subscription) return
    if (!confirm("Push通知を解除しますか？")) return

    this.setLoading(this.unsubscribeButtonTarget, true)
    try {
      await this.deleteSubscription(this.subscription)
      await this.subscription.unsubscribe()
      this.subscription = null
      this.showStatus("Push通知を解除しました。", "success")
      this.updateUI()
    } catch (e) {
      this.showStatus(`解除に失敗しました: ${e.message}`, "error")
    } finally {
      this.setLoading(this.unsubscribeButtonTarget, false)
    }
  }

  async test() {
    if (!this.subscription) return

    this.setLoading(this.testButtonTarget, true)
    try {
      const response = await fetch("/push-subscription/test", {
        method: "POST",
        headers: this.headers()
      })
      const data = await response.json()

      if (response.ok) {
        this.showStatus("テスト通知を送信しました。", "success")
      } else {
        this.showStatus(data.error || "テスト通知の送信に失敗しました。", "error")
      }
    } catch (e) {
      this.showStatus(`送信に失敗しました: ${e.message}`, "error")
    } finally {
      this.setLoading(this.testButtonTarget, false)
    }
  }

  async saveSubscription(subscription) {
    await fetch("/push-subscription", {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({ subscription: subscription.toJSON() })
    })
  }

  async deleteSubscription(subscription) {
    await fetch("/push-subscription", {
      method: "DELETE",
      headers: this.headers(),
      body: JSON.stringify({ endpoint: subscription.endpoint })
    })
  }

  headers() {
    return {
      "Content-Type": "application/json",
      "X-CSRF-Token": this.csrfToken()
    }
  }

  csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }

  updateUI() {
    const active = !!this.subscription

    // 有効化ボタン: subscription がなければ表示
    if (this.hasSubscribeButtonTarget) {
      this.subscribeButtonTarget.classList.toggle("hidden", active)
      this.subscribeButtonTarget.disabled = !this.supported || !this.publicKeyValue
    }
    // 解除・テストボタン: subscription があれば表示
    if (this.hasUnsubscribeButtonTarget) {
      this.unsubscribeButtonTarget.classList.toggle("hidden", !active)
    }
    if (this.hasTestButtonTarget) {
      this.testButtonTarget.classList.toggle("hidden", !active)
    }
    // バッジ
    if (this.hasBadgeTarget) {
      if (active) {
        this.badgeTarget.textContent = "有効"
        this.badgeTarget.style.background = "var(--color-success-light)"
        this.badgeTarget.style.color = "var(--color-success)"
      } else {
        this.badgeTarget.textContent = "無効"
        this.badgeTarget.style.background = "var(--color-bg-hover)"
        this.badgeTarget.style.color = "var(--color-text-muted)"
      }
    }
  }

  showStatus(message, type) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("hidden")
    if (type === "success") {
      this.statusTarget.style.color = "var(--color-success)"
    } else if (type === "error") {
      this.statusTarget.style.color = "var(--color-error)"
    } else {
      this.statusTarget.style.color = ""
    }
    // 5秒後に自動非表示
    clearTimeout(this._statusTimer)
    this._statusTimer = setTimeout(() => {
      this.statusTarget.classList.add("hidden")
    }, 5000)
  }

  setLoading(button, loading) {
    if (!button) return
    button.disabled = loading
    if (loading) {
      button.dataset.originalText = button.textContent
      button.textContent = "..."
    } else if (button.dataset.originalText) {
      button.textContent = button.dataset.originalText
      delete button.dataset.originalText
    }
  }

  decodeKey(base64) {
    const padding = "=".repeat((4 - (base64.length % 4)) % 4)
    const safe = (base64 + padding).replace(/-/g, "+").replace(/_/g, "/")
    const raw = atob(safe)
    const buffer = new Uint8Array(raw.length)
    for (let i = 0; i < raw.length; i += 1) {
      buffer[i] = raw.charCodeAt(i)
    }
    return buffer
  }
}
