import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["postalCode", "address", "status", "latitude", "longitude"]

  connect() {
    this.lastLookup = null
    this.lastGeocode = null
  }

  normalize() {
    if (!this.hasPostalCodeTarget) return

    const digits = this.postalCodeTarget.value.replace(/\D/g, "")
    this.postalCodeTarget.value = digits.slice(0, 7)
  }

  geocodeFromAddress() {
    if (!this.hasAddressTarget) return

    const address = this.addressTarget.value.trim()
    if (!address) {
      this.clearCoordinates()
      return
    }

    this.geocode(address)
  }

  lookup() {
    if (!this.hasPostalCodeTarget || !this.hasAddressTarget) return

    const postalCode = this.postalCodeTarget.value.replace(/\D/g, "")
    if (postalCode.length !== 7) {
      this.updateStatus("郵便番号は7桁で入力してください。")
      return
    }

    if (postalCode === this.lastLookup) return

    this.lastLookup = postalCode
    this.updateStatus("住所を検索中...")
    const url = `https://zipcloud.ibsnet.co.jp/api/search?zipcode=${postalCode}`

    fetch(url, { headers: { Accept: "application/json" } })
      .then((response) => response.json())
      .then((data) => {
        if (data?.results?.length) {
          const result = data.results[0]
          const address = `${result.address1}${result.address2}${result.address3}`
          this.addressTarget.value = address
          this.updateStatus("住所を自動入力しました。")
          this.geocode(address)
        } else {
          this.updateStatus("住所が見つかりませんでした。郵便番号を確認してください。")
          this.clearCoordinates()
        }
      })
      .catch(() => {
        this.lastLookup = null
        this.updateStatus("住所の取得に失敗しました。通信環境を確認してください。")
        this.clearCoordinates()
      })
  }

  geocode(address) {
    const normalized = address.trim()
    if (!normalized) {
      this.clearCoordinates()
      return
    }

    if (normalized === this.lastGeocode) return
    this.lastGeocode = normalized

    const url = `https://msearch.gsi.go.jp/address-search/AddressSearch?q=${encodeURIComponent(normalized)}`
    fetch(url, { headers: { Accept: "application/json" } })
      .then((response) => response.json())
      .then((data) => {
        if (Array.isArray(data) && data.length) {
          const [lng, lat] = data[0].geometry.coordinates
          this.setCoordinates(lat, lng)
          this.updateStatus("住所の位置情報を更新しました。")
        } else {
          this.updateStatus("住所の位置情報が取得できませんでした。住所を確認してください。")
          this.clearCoordinates()
        }
      })
      .catch(() => {
        this.updateStatus("位置情報の取得に失敗しました。通信環境を確認してください。")
        this.clearCoordinates()
      })
  }

  setCoordinates(lat, lng) {
    if (this.hasLatitudeTarget) this.latitudeTarget.value = lat
    if (this.hasLongitudeTarget) this.longitudeTarget.value = lng
  }

  clearCoordinates() {
    if (this.hasLatitudeTarget) this.latitudeTarget.value = ""
    if (this.hasLongitudeTarget) this.longitudeTarget.value = ""
  }

  updateStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }
}
