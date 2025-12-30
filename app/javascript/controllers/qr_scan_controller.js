import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["video", "manual", "status", "tokenInput", "form"]
  static values = { submitOnScan: Boolean }

  connect() {
    this.scanning = false
    this.scanBusy = false
    this.supported =
      "BarcodeDetector" in window &&
      navigator.mediaDevices &&
      navigator.mediaDevices.getUserMedia

    if (!this.supported) {
      this.showManual()
      this.updateStatus("unsupported")
      return
    }

    this.detector = new BarcodeDetector({ formats: ["qr_code"] })
    this.updateStatus("ready")
  }

  disconnect() {
    this.stop()
  }

  start() {
    if (!this.supported || this.scanning) return

    navigator.mediaDevices
      .getUserMedia({ video: { facingMode: "environment" }, audio: false })
      .then((stream) => {
        this.stream = stream
        this.videoTarget.srcObject = stream
        this.videoTarget.play()
        this.scanning = true
        this.updateStatus("scanning")
        this.startLoop()
      })
      .catch(() => {
        this.showManual()
        this.updateStatus("permission")
      })
  }

  stop() {
    this.scanning = false

    if (this.scanTimer) {
      clearInterval(this.scanTimer)
      this.scanTimer = null
    }

    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop())
      this.stream = null
    }
  }

  toggleManual() {
    if (!this.hasManualTarget) return
    this.manualTarget.classList.toggle("hidden")
  }

  startLoop() {
    if (this.scanTimer) return
    this.scanTimer = setInterval(() => this.scanFrame(), 400)
  }

  async scanFrame() {
    if (!this.scanning || this.scanBusy) return
    this.scanBusy = true

    try {
      const barcodes = await this.detector.detect(this.videoTarget)
      if (barcodes.length > 0) {
        this.handleResult(barcodes[0].rawValue)
      }
    } catch (_error) {
      this.showManual()
      this.updateStatus("error")
    } finally {
      this.scanBusy = false
    }
  }

  handleResult(value) {
    if (!value) return

    if (this.hasTokenInputTarget) {
      this.tokenInputTarget.value = value
    }

    this.updateStatus("detected")
    this.stop()

    if (this.submitOnScanValue && this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  showManual() {
    if (this.hasManualTarget) {
      this.manualTarget.classList.remove("hidden")
    }
  }

  updateStatus(state) {
    if (!this.hasStatusTarget) return
    const key = `${state}Message`
    const message = this.statusTarget.dataset[key]
    if (message) {
      this.statusTarget.textContent = message
    }
  }
}
