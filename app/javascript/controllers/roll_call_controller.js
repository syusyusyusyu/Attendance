import { Controller } from "@hotwired/stimulus"

const STATUS_LABELS = {
  present: "出席",
  absent: "欠席",
  late: "遅刻",
  excused: "公欠",
  early_leave: "早退"
}

const STATUS_BADGE_CLASSES = {
  present: "badge badge-success",
  absent: "badge badge-error",
  late: "badge badge-warning",
  excused: "badge badge-info",
  early_leave: "badge badge-warning"
}

export default class extends Controller {
  static targets = ["counter", "progressBar", "radio", "badge"]

  statusChanged(event) {
    this.updateBadge(event.target)
    this.updateProgress()
  }

  selectAll() {
    // QR確認済み以外の学生の「出席(present)」ラジオボタンを全選択
    const radios = this.radioTargets.filter(r => r.value === "present")
    radios.forEach(radio => {
      radio.checked = true
      this.updateBadge(radio)
    })
    this.updateProgress()
  }

  updateBadge(radio) {
    // name="attendance[123]" → studentId="123"
    const match = radio.name.match(/attendance\[(\d+)\]/)
    if (!match) return

    const studentId = match[1]
    const badge = this.badgeTargets.find(b => b.dataset.studentId === studentId)
    if (!badge) return

    const status = radio.value
    badge.textContent = STATUS_LABELS[status] || status
    badge.className = STATUS_BADGE_CLASSES[status] || "badge"
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
