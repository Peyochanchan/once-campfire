function extractFromMeta(name) {
  return document.head.querySelector(`meta[name="${name}"]`)?.getAttribute("content")
}

export function currentUser() {
  const id = extractFromMeta("current-user-id")
  if (id) return { id: parseInt(id), name: extractFromMeta("current-user-name") }
}

export function currentRoom() {
  const id = extractFromMeta("current-room-id")
  if (id) return { id: parseInt(id) }
}
