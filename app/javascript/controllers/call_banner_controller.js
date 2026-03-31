import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["joinBtn", "leaveBtn"]
  static values = { participantIds: Array, notify: { type: Boolean, default: false } }

  connect() {
    const currentUserId = parseInt(document.head.querySelector('meta[name="current-user-id"]')?.content)
    const isInCall = this.participantIdsValue.includes(currentUserId)

    if (isInCall) {
      this.joinBtnTarget.style.display = "none"
      this.leaveBtnTarget.style.display = ""
    } else {
      this.joinBtnTarget.style.display = ""
      this.leaveBtnTarget.style.display = "none"

      if (this.notifyValue) {
        const soundUrl = document.head.querySelector('meta[name="current-user-ringtone"]')?.content
        if (soundUrl) new Audio(soundUrl).play().catch(() => {})
      }
    }
  }
}
