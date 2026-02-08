import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["counter", "progressBar", "radio"]

  statusChanged() {
    this.updateProgress()
  }

  selectAll() {
    // QR確認済み以外の学生の「出席(present)」ラジオボタンを全選択
    const radios = this.radioTargets.filter(r => r.value === "present")
    radios.forEach(radio => {
      radio.checked = true
    })
    this.updateProgress()
  }

  updateProgress() {
    if (!this.hasCounterTarget || !this.hasProgressBarTarget) return

    // ラジオボタンが選択されている学生数をカウント（＝何らかのステータスが入った）
    const allNames = new Set(this.radioTargets.map(r => r.name))
    const selectedNames = new Set(
      this.radioTargets.filter(r => r.checked).map(r => r.name)
    )

    // QR確認済み（ラジオなし）の学生数
    const total = parseInt(this.counterTarget.textContent.split("/")[1]) || 0
    const qrConfirmed = total - allNames.size
    const confirmed = selectedNames.size + qrConfirmed

    this.counterTarget.textContent = `${confirmed} / ${total} 人`
    const percent = total > 0 ? Math.round((confirmed / total) * 100) : 0
    this.progressBarTarget.style.width = `${percent}%`
  }
}
