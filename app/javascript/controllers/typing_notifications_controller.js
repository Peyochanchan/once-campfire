import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"
import { throttle } from "../helpers/timing_helpers"
import { pageIsTurboPreview } from "../helpers/turbo_helpers"
import TypingTracker from "../models/typing_tracker"
import { currentRoom, currentUser } from "../initializers/current"

export default class extends Controller {
  static targets = [ "author", "indicator" ]
  static classes = [ "active" ]

  async connect() {
    if (!pageIsTurboPreview()) {
      this.tracker = new TypingTracker(this.#update.bind(this))

      this.channel = await cable.subscribeTo(
        { channel: "TypingNotificationsChannel", room_id: currentRoom().id },
        { received: this.#received.bind(this) }
      )
    }
  }

  disconnect() {
    this.tracker?.close()
    this.channel?.unsubscribe()
  }

  start({ target }) {
    if (target.value) {
      this.#throttledSend("start")
    } else {
      this.#send("stop")
    }
  }

  stop() {
    this.#send("stop");
  }

  #received({ action, user }) {
    if (user.id !== currentUser().id) {
      if (action === "start") {
        this.tracker.add(user.name)
      } else {
        this.tracker.remove(user.name)
      }
    }
  }

  #send(action) {
    this.channel.send({ action })
  }

  #update(message) {
    this.authorTarget.textContent = message
    this.indicatorTarget.classList.toggle(this.activeClass, !!message)
  }

  #throttledSend = throttle(action => this.#send(action))
}
