import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["digit", "hidden"]

  connect() {
    this.digitTargets[0]?.focus()
  }

  input(event) {
    const input = event.target
    const index = this.digitTargets.indexOf(input)
    const value = input.value

    // Only allow single digit
    if (value.length > 1) {
      input.value = value[value.length - 1]
    }

    // Move to next field
    if (input.value && index < this.digitTargets.length - 1) {
      this.digitTargets[index + 1].focus()
    }

    this._updateHidden()
  }

  keydown(event) {
    const input = event.target
    const index = this.digitTargets.indexOf(input)

    if (event.key === "Backspace" && !input.value && index > 0) {
      this.digitTargets[index - 1].focus()
      this.digitTargets[index - 1].value = ""
      this._updateHidden()
    }
  }

  paste(event) {
    event.preventDefault()
    const text = (event.clipboardData || window.clipboardData).getData("text").replace(/\D/g, "").slice(0, 6)

    text.split("").forEach((char, i) => {
      if (this.digitTargets[i]) {
        this.digitTargets[i].value = char
      }
    })

    const lastIndex = Math.min(text.length, this.digitTargets.length) - 1
    if (lastIndex >= 0) this.digitTargets[lastIndex].focus()

    this._updateHidden()
  }

  _updateHidden() {
    this.hiddenTarget.value = this.digitTargets.map(d => d.value).join("")
  }
}
