import { Controller } from "@hotwired/stimulus"
import "jsqr"

export default class extends Controller {
  static targets = [
    "video",
    "manual",
    "status",
    "tokenInput",
    "form",
    "latitude",
    "longitude",
    "accuracy",
    "locationSource"
  ]
  static values = { submitOnScan: Boolean, locationRequired: { type: Boolean, default: true } }

  connect() {
    this.scanning = false
    this.scanBusy = false
    this.submitting = false
    this.detectorSupported = "BarcodeDetector" in window
    this.jsQrSupported = typeof window.jsQR === "function"
    this.supported =
      navigator.mediaDevices &&
      navigator.mediaDevices.getUserMedia &&
      (this.detectorSupported || this.jsQrSupported)
    this.locationSupported = "geolocation" in navigator
    this.locationCapturedAt = null
    this.locationPromise = null
    this.locationMaxAgeMs = 60 * 1000

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
    if (this.locationRequiredValue && !this.locationSupported) {
      this.updateStatus("locationUnsupported")
      return
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
    if (this.locationRequiredValue && !this.locationSupported) {
      this.updateStatus("locationUnsupported")
      return
    }

    if (this.locationRequiredValue) {
      this.captureLocation()
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
    this.vibrateSuccess()
    this.stop()

    if (this.submitOnScanValue && this.hasFormTarget) {
      this.submitWithLocation()
    }
  }

  prepareSubmit(event) {
    if (!this.locationRequiredValue || this.submitting) return
    if (this.locationReady()) return

    event.preventDefault()
    this.submitWithLocation()
  }

  async submitWithLocation() {
    if (!this.hasFormTarget || this.submitting) return

    const ready = await this.ensureLocation()
    if (!ready) return

    this.submitting = true
    this.formTarget.requestSubmit()
    this.submitting = false
  }

  locationReady() {
    return (
      this.hasLatitudeTarget &&
      this.hasLongitudeTarget &&
      this.latitudeTarget.value &&
      this.longitudeTarget.value &&
      !this.locationStale()
    )
  }

  locationStale() {
    if (!this.locationCapturedAt) return true
    return Date.now() - this.locationCapturedAt > this.locationMaxAgeMs
  }

  async ensureLocation() {
    if (!this.locationRequiredValue) return true
    if (!this.locationSupported) {
      this.updateStatus("locationUnsupported")
      return false
    }
    if (this.locationReady()) return true

    return this.captureLocation()
  }

  async captureLocation() {
    if (this.locationPromise) return this.locationPromise
    if (!this.locationSupported) return false

    this.updateStatus("locating")

    this.locationPromise = new Promise((resolve) => {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          this.setLocation(position)
          this.locationPromise = null
          if (this.scanning) {
            this.updateStatus("scanning")
          } else {
            this.updateStatus("ready")
          }
          resolve(true)
        },
        (error) => {
          this.locationPromise = null
          this.handleLocationError(error)
          resolve(false)
        },
        {
          enableHighAccuracy: true,
          timeout: 10000,
          maximumAge: 0
        }
      )
    })

    return this.locationPromise
  }

  setLocation(position) {
    if (!position || !this.hasLatitudeTarget || !this.hasLongitudeTarget) return

    const { latitude, longitude, accuracy } = position.coords
    this.latitudeTarget.value = latitude
    this.longitudeTarget.value = longitude
    if (this.hasAccuracyTarget && accuracy !== undefined && accuracy !== null) {
      this.accuracyTarget.value = accuracy
    }
    if (this.hasLocationSourceTarget) {
      this.locationSourceTarget.value = "geolocation"
    }
    this.locationCapturedAt = Date.now()
  }

  handleLocationError(error) {
    if (!error) {
      this.updateStatus("locationRequired")
      return
    }

    switch (error.code) {
      case error.PERMISSION_DENIED:
        this.updateStatus("locationDenied")
        break
      case error.POSITION_UNAVAILABLE:
        this.updateStatus("locationUnavailable")
        break
      case error.TIMEOUT:
        this.updateStatus("locationTimeout")
        break
      default:
        this.updateStatus("locationRequired")
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

  vibrateSuccess() {
    if (navigator.vibrate) {
      navigator.vibrate([60])
    }
  }
}
