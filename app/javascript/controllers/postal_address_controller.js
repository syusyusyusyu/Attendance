import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["postalCode", "address", "status"]

  connect() {
    this.lastLookup = null
  }

  normalize() {
    if (!this.hasPostalCodeTarget) return

    const digits = this.postalCodeTarget.value.replace(/\D/g, "")
    this.postalCodeTarget.value = digits.slice(0, 7)
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
        } else {
          this.updateStatus("住所が見つかりませんでした。郵便番号を確認してください。")
        }
      })
      .catch(() => {
        this.lastLookup = null
        this.updateStatus("住所の取得に失敗しました。通信環境を確認してください。")
      })
  }

  updateStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }
}
