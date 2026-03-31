// Highlight active room in sidebar
function highlightActiveRoom() {
  const currentRoomId = document.head.querySelector('meta[name="current-room-id"]')?.content
  if (!currentRoomId) return false

  document.querySelectorAll(".room.room--active").forEach(el => {
    el.classList.remove("room--active")
  })

  const activeRoom = document.querySelector(`#shared_rooms [data-room-id="${currentRoomId}"]`)
  if (activeRoom) {
    activeRoom.classList.add("room--active")
    return true
  }
  return false
}

function pollHighlight() {
  let attempts = 0
  const t = setInterval(() => {
    if (highlightActiveRoom() || attempts++ > 30) clearInterval(t)
  }, 100)
}

pollHighlight()
document.addEventListener("turbo:load", pollHighlight)
document.addEventListener("turbo:frame-load", highlightActiveRoom)
