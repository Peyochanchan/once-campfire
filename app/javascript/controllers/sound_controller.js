import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, autoplay: { type: Boolean, default: false } }

  connect() {
    if (this.autoplayValue) {
      this.play()
    }
  }

  disconnect() {
    this.stop()
  }

  play() {
    this._sound = new Audio(this.urlValue)
    this._sound.play().catch(() => {})
  }

  stop() {
    if (this._sound) {
      this._sound.pause()
      this._sound.currentTime = 0
      this._sound = null
    }
  }
}
