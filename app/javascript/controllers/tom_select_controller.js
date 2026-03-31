import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async connect() {
    const { default: TomSelect } = await import("tom-select")

    if (this.element.tomselect) return

    this.tomSelect = new TomSelect(this.element, {
      create: false,
      controlInput: null,
      allowEmptyOption: false
    })
  }

  disconnect() {
    if (this.tomSelect) {
      this.tomSelect.destroy()
      this.tomSelect = null
    }
  }
}
