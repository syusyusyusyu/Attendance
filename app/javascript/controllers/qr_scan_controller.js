import { Controller } from "@hotwired/stimulus"
import "jsqr"

export default class extends Controller {
  static targets = ["video", "manual", "status", "tokenInput", "form"]
  static values = { submitOnScan: Boolean }

  connect() {
    this.scanning = false
    this.scanBusy = false
    this.detectorSupported = "BarcodeDetector" in window
    this.jsQrSupported = typeof window.jsQR === "function"
    this.supported =
      navigator.mediaDevices &&
      navigator.mediaDevices.getUserMedia &&
      (this.detectorSupported || this.jsQrSupported)

    if (!this.supported) {
      this.showManual()
      this.updateStatus("unsupported")
      return
    }

    if (this.detectorSupported) {
      this.detector = new BarcodeDetector({ formats: ["qr_code"] })
      if (typeof BarcodeDetector.getSupportedFormats === "function") {
        BarcodeDetector.getSupportedFormats()
          .then((formats) => {
            if (!formats.includes("qr_code")) {
              this.detector = null
              if (!this.jsQrSupported) {
                this.supported = false
                this.showManual()
                this.updateStatus("unsupported")
              }
            }
          })
          .catch(() => {})
      }
    }
    this.updateStatus("ready")
  }

  disconnect() {
    this.stop()
  }

  start() {
    if (!this.supported || this.scanning) return
    if (!this.detector && !this.jsQrSupported) {
      this.showManual()
      this.updateStatus("unsupported")
      return
    }

    const constraints = {
      video: {
        facingMode: { ideal: "environment" },
        width: { ideal: 1280 },
        height: { ideal: 720 }
      },
      audio: false
    }

    navigator.mediaDevices
      .getUserMedia(constraints)
      .then((stream) => {
        this.stream = stream
        this.videoTarget.setAttribute("playsinline", "")
        this.videoTarget.setAttribute("autoplay", "")
        this.videoTarget.muted = true
        this.videoTarget.srcObject = stream
        this.videoTarget.onloadedmetadata = () => {
          this.videoTarget.play()
          this.scanning = true
          this.updateStatus("scanning")
          this.prepareCanvas()
          this.startLoop()
        }
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
    this.canvas = null
    this.canvasContext = null
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
      let detected = false

      if (this.detector) {
        const barcodes = await this.detector.detect(this.videoTarget)
        if (barcodes.length > 0) {
          this.handleResult(barcodes[0].rawValue)
          detected = true
        }
      }

      if (!detected && this.jsQrSupported) {
        this.scanWithJsQr()
      }
    } catch (_error) {
      if (this.jsQrSupported) {
        this.detector = null
        this.scanWithJsQr()
      } else {
        this.showManual()
        this.updateStatus("error")
      }
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

  prepareCanvas() {
    if (!this.jsQrSupported || this.canvas) return

    this.canvas = document.createElement("canvas")
    this.canvasContext = this.canvas.getContext("2d", { willReadFrequently: true })
  }

  scanWithJsQr() {
    if (!this.canvasContext) return
    if (this.videoTarget.readyState < 2) return

    const width = this.videoTarget.videoWidth
    const height = this.videoTarget.videoHeight
    if (!width || !height) return

    this.canvas.width = width
    this.canvas.height = height
    this.canvasContext.drawImage(this.videoTarget, 0, 0, width, height)
    const imageData = this.canvasContext.getImageData(0, 0, width, height)
    const code = window.jsQR(imageData.data, width, height, {
      inversionAttempts: "attemptBoth"
    })

    if (code && code.data) {
      this.handleResult(code.data)
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
