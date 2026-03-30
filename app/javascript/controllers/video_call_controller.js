import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["grid", "cameraBtn", "micBtn", "screenBtn"]
  static values = {
    token: String,
    url: String,
    roomId: Number,
    leaveUrl: String,
    avatarUrl: String,
    startWithVideo: { type: Boolean, default: true }
  }

  connect() {
    if (this.hasTokenValue && this.tokenValue) {
      this._joinRoom()
    }
    this._boundBeforeUnload = this._beforeUnload.bind(this)
    window.addEventListener("beforeunload", this._boundBeforeUnload)
    this._setupControlsAutoHide()
  }

  disconnect() {
    window.removeEventListener("beforeunload", this._boundBeforeUnload)
    clearTimeout(this._controlsTimer)
    this._cleanup()
  }

  showControls() {
    this.element.classList.add("call-container--controls-visible")
    clearTimeout(this._controlsTimer)
    this._controlsTimer = setTimeout(() => {
      this.element.classList.remove("call-container--controls-visible")
    }, 4000)
  }

  _setupControlsAutoHide() {
    this.element.addEventListener("mousemove", () => this.showControls())
    this.element.addEventListener("touchstart", () => this.showControls())
    this.showControls()
  }

  async toggleCamera() {
    if (!this.room) return
    const wasEnabled = this.room.localParticipant.isCameraEnabled
    await this.room.localParticipant.setCameraEnabled(!wasEnabled)
    this.cameraBtnTarget.classList.toggle("btn--active", !wasEnabled)

    if (wasEnabled) {
      // Camera off: show avatar, remove videos
      this._toggleAvatar(this.room.localParticipant, true)
    } else {
      // Camera on: hide avatar, re-attach video
      this._toggleAvatar(this.room.localParticipant, false)
      this._attachLocalTracks()
    }
  }

  async toggleMic() {
    if (!this.room) return
    const enabled = this.room.localParticipant.isMicrophoneEnabled
    await this.room.localParticipant.setMicrophoneEnabled(!enabled)
    this.micBtnTarget.classList.toggle("btn--active", !enabled)
  }

  async toggleScreenShare() {
    if (!this.room) return
    try {
      const enabled = this.room.localParticipant.isScreenShareEnabled
      await this.room.localParticipant.setScreenShareEnabled(!enabled)
      this.screenBtnTarget.classList.toggle("btn--active", !enabled)
    } catch (error) {
      console.warn("[VideoCall] Screen share not available:", error.message)
    }
  }

  async leave() {
    this._cleanup()

    const token = document.querySelector('meta[name="csrf-token"]').content
    await fetch(this.leaveUrlValue, {
      method: "DELETE",
      headers: { "X-CSRF-Token": token }
    })
    window.close()
  }

  // Private

  async _joinRoom() {
    const { Room, RoomEvent } = window.LivekitClient

    this.room = new Room({ adaptiveStream: true, dynacast: true })

    this.room.on(RoomEvent.TrackSubscribed, (track, _publication, participant) => {
      this._attachTrack(track, participant)
    })

    this.room.on(RoomEvent.TrackUnsubscribed, (track, _publication, _participant) => {
      this._detachTrack(track)
    })

    this.room.on(RoomEvent.LocalTrackPublished, (publication) => {
      if (publication.track) {
        this._attachTrack(publication.track, this.room.localParticipant)
      }
    })

    this.room.on(RoomEvent.TrackMuted, (publication, participant) => {
      if (publication.kind === "video" && publication.source === "camera") {
        this._toggleAvatar(participant, true)
      }
    })

    this.room.on(RoomEvent.TrackUnmuted, (publication, participant) => {
      if (publication.kind === "video" && publication.source === "camera") {
        this._toggleAvatar(participant, false)
      }
    })

    this.room.on(RoomEvent.ParticipantDisconnected, (participant) => {
      this._removeParticipantTile(participant)
    })

    this.room.on(RoomEvent.Disconnected, () => {
      this._cleanup()
    })

    try {
      await this.room.connect(this.urlValue, this.tokenValue)

      // Always create local tile upfront
      this._getOrCreateTile(this.room.localParticipant)

      if (this.startWithVideoValue) {
        await this.room.localParticipant.enableCameraAndMicrophone()
        this._attachLocalTracks()
        this.cameraBtnTarget.classList.add("btn--active")
      } else {
        await this.room.localParticipant.setMicrophoneEnabled(true)
        this._toggleAvatar(this.room.localParticipant, true)
      }
      this.micBtnTarget.classList.add("btn--active")
    } catch (error) {
      console.error("[VideoCall] Failed to connect:", error)
    }
  }

  _attachTrack(track, participant) {
    if (!this.hasGridTarget) return

    const isLocal = participant === this.room.localParticipant
    if (isLocal && track.kind === "audio") return

    const tile = this._getOrCreateTile(participant)
    const element = track.attach()
    element.dataset.trackSid = track.sid
    if (track.source === "screen_share") {
      element.classList.add("call-tile__screen")
    }
    tile.appendChild(element)
  }

  _attachLocalTracks() {
    const lp = this.room.localParticipant
    const tile = this._getOrCreateTile(lp)
    lp.videoTrackPublications.forEach(pub => {
      if (pub.track && pub.source === "camera") {
        const el = pub.track.attach()
        tile.appendChild(el)
      }
    })
  }

  _detachTrack(track) {
    track.detach().forEach(el => el.remove())
  }

  _getOrCreateTile(participant) {
    let tile = this._findTile(participant)
    if (!tile) {
      tile = document.createElement("div")
      tile.className = "call-tile"
      tile.dataset.participantIdentity = participant.identity

      // Avatar placeholder (shown when camera is off)
      const avatar = document.createElement("div")
      avatar.className = "call-tile__avatar"
      avatar.style.display = "none"
      avatar.style.alignItems = "center"
      avatar.style.justifyContent = "center"
      avatar.style.width = "100%"
      avatar.style.height = "100%"
      const avatarImg = document.createElement("img")
      avatarImg.src = this._avatarUrlFor(participant)
      avatarImg.alt = participant.name || participant.identity
      avatarImg.style.width = "100%"
      avatarImg.style.height = "100%"
      avatarImg.style.objectFit = "cover"
      avatar.appendChild(avatarImg)
      tile.appendChild(avatar)

      const nameTag = document.createElement("span")
      nameTag.className = "call-tile__name txt-small"
      nameTag.textContent = participant.name || participant.identity
      tile.appendChild(nameTag)

      this.gridTarget.appendChild(tile)
    }
    return tile
  }

  _avatarUrlFor(participant) {
    const isLocal = this.room && participant === this.room.localParticipant
    if (isLocal && this.hasAvatarUrlValue) {
      return this.avatarUrlValue
    }
    // For remote participants, use a generated avatar based on identity
    return `/users/${participant.identity}/avatar`
  }

  _toggleAvatar(participant, showAvatar) {
    const tile = this._findTile(participant)
    if (!tile) return

    // Hide/show all video elements
    tile.querySelectorAll("video").forEach(v => v.style.display = showAvatar ? "none" : "block")

    // Show/hide avatar
    const avatar = tile.querySelector(".call-tile__avatar")
    if (avatar) avatar.style.display = showAvatar ? "flex" : "none"
  }

  _findTile(participant) {
    return this.gridTarget.querySelector(`[data-participant-identity="${participant.identity}"]`)
  }

  _removeParticipantTile(participant) {
    this._findTile(participant)?.remove()
  }

  _cleanup() {
    if (this.room) {
      this.room.disconnect()
      this.room = null
    }
  }

  _beforeUnload() {
    if (this.room) {
      this.room.disconnect()
      const token = document.querySelector('meta[name="csrf-token"]').content
      fetch(this.leaveUrlValue, {
        method: "DELETE",
        headers: { "X-CSRF-Token": token },
        keepalive: true
      })
    }
  }
}
