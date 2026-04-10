import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "frame"]

  open(event) {
    const messageId = event.params.messageId || event.currentTarget.dataset.threadPanelMessageIdParam
    if (!messageId) return

    // Highlight the parent message in the feed
    this.clearHighlight()
    const msg = document.querySelector(`[data-message-id="${messageId}"]`)
    if (msg) msg.classList.add("message--thread-active")
    this.activeMessageId = messageId

    this.panelTarget.classList.add("thread-panel--open")
    this.frameTarget.setAttribute("src", `/messages/${messageId}/thread`)
  }

  close() {
    this.clearHighlight()
    this.panelTarget.classList.remove("thread-panel--open")
    this.frameTarget.removeAttribute("src")
    this.frameTarget.innerHTML = ""
  }

  submitForm(event) {
    event.preventDefault()
    const input = event.currentTarget
    if (input.value.trim() === "") return
    input.closest("form").requestSubmit()
  }

  clearHighlight() {
    document.querySelectorAll(".message--thread-active").forEach(el => {
      el.classList.remove("message--thread-active")
    })
  }
}
