import { Controller } from "@hotwired/stimulus"
import { currentUser } from "../initializers/current"

export default class extends Controller {
  static classes = [ "reveal", "perform" ]
  static targets = [ "button", "content" ]
  static values = { boosterId: Number }

  connect() {
    if (this.#currentUserIsBooster) {
      this.#setAccessibleAttributes()
    }
  }

  reveal() {
    if (this.#currentUserIsBooster) {
      this.element.classList.toggle(this.revealClass)
      this.buttonTarget.focus()
    }
  }

  perform() {
    this.element.classList.add(this.performClass)
  }

  #setAccessibleAttributes() {
    this.contentTarget.setAttribute('tabindex', '0')
    this.contentTarget.setAttribute('aria-describedby', 'delete_boost_accessible_label')
  }

  get #currentUserIsBooster() {
    return currentUser().id === this.boosterIdValue
  }
}
