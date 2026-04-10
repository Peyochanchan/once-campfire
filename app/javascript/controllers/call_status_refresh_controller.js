import { Controller } from "@hotwired/stimulus"

// Refreshes the sidebar whenever the call banner is re-rendered (participant join/leave)
export default class extends Controller {
  connect() {
    const sidebar = document.getElementById("user_sidebar")
    if (sidebar && sidebar.src) {
      sidebar.src = sidebar.src
    }
  }
}
