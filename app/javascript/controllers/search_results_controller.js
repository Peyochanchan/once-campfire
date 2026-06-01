import { Controller } from "@hotwired/stimulus"
import MessageFormatter, { ThreadStyle } from "../models/message_formatter"
import { currentUser } from "../initializers/current"

export default class extends Controller {
  static targets = [ "message" ]
  static classes = [ "me", "threaded", "mentioned", "formatted" ]

  #formatter

  initialize() {
    this.#formatter = new MessageFormatter(currentUser().id, {
      formatted: this.formattedClass,
      me: this.meClass,
      mentioned: this.mentionedClass,
      threaded: this.threadedClass,
    })
  }

  connect() {
    this.element.scrollTo({ top: this.element.scrollHeight })
  }

  messageTargetConnected(target) {
    this.#formatter.format(target, ThreadStyle.none)
  }
}
