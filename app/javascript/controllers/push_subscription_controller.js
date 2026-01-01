import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "subscribeButton", "unsubscribeButton"]
  static values = { publicKey: String }

  connect() {
    this.supported = "serviceWorker" in navigator && "PushManager" in window
    this.updateButtons()
    if (!this.supported || !this.publicKeyValue) {
      this.updateStatus("このブラウザではPush通知を利用できません。")
      return
    }

    this.refreshSubscription()
  }

  async refreshSubscription() {
    const registration = await navigator.serviceWorker.getRegistration()
    this.subscription = registration ? await registration.pushManager.getSubscription() : null
    this.updateButtons()
  }

  async subscribe() {
    if (!this.supported || !this.publicKeyValue) return

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
    this.updateStatus("Push通知を有効化しました。")
    this.updateButtons()
  }

  async unsubscribe() {
    if (!this.subscription) return

    await this.deleteSubscription(this.subscription)
    await this.subscription.unsubscribe()
    this.subscription = null
    this.updateStatus("Push通知を解除しました。")
    this.updateButtons()
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

  updateButtons() {
    if (this.hasSubscribeButtonTarget) {
      this.subscribeButtonTarget.disabled = !this.supported || !this.publicKeyValue
    }
    if (this.hasUnsubscribeButtonTarget) {
      this.unsubscribeButtonTarget.disabled = !this.subscription
    }
  }

  updateStatus(message) {
    if (this.hasStatusTarget && message) {
      this.statusTarget.textContent = message
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
