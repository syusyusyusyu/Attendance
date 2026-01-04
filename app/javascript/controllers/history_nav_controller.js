import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["back", "forward"]

  back() {
    window.history.back()
  }

  forward() {
    window.history.forward()
  }
}
