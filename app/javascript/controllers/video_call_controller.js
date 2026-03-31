import { Controller } from "@hotwired/stimulus"
import { Room, RoomEvent } from "livekit-client"
import { BackgroundProcessor } from "@livekit/track-processors"
import TomSelect from "tom-select"

export default class extends Controller {
  static targets = ["grid", "cameraBtn", "micBtn", "screenBtn", "blurBtn", "settingsBtn", "settingsPanel", "cameraSelect", "micSelect", "speakerSelect", "chatBtn", "chatPanel"]
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
    this._startCallStatusPoll()
  }

  disconnect() {
    window.removeEventListener("beforeunload", this._boundBeforeUnload)
    clearTimeout(this._controlsTimer)
    clearInterval(this._statusPollTimer)
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
    this._toggleIconState(this.cameraBtnTarget, !wasEnabled)

    if (wasEnabled) {
      this._toggleAvatar(this.room.localParticipant, true)
    } else {
      this._toggleAvatar(this.room.localParticipant, false)
      this._attachLocalTracks()
    }
  }

  async toggleMic() {
    if (!this.room) return
    const enabled = this.room.localParticipant.isMicrophoneEnabled
    await this.room.localParticipant.setMicrophoneEnabled(!enabled)
    this.micBtnTarget.classList.toggle("btn--active", !enabled)
    this._toggleIconState(this.micBtnTarget, !enabled)
  }

  async toggleBlur() {
    if (!this.room) return
    const cameraPub = this.room.localParticipant.getTrackPublication("camera")
    if (!cameraPub || !cameraPub.track) return

    try {
      if (this._blurEnabled) {
        await cameraPub.track.stopProcessor()
        this._blurEnabled = false
      } else {
        if (!this._blurProcessor) {
          this._blurProcessor = BackgroundProcessor({
            mode: "background-blur",
            blurRadius: 18,
            segmenterOptions: {
              modelType: "landscape",
              smoothingFactor: 0.8
            }
          })
        }
        await cameraPub.track.setProcessor(this._blurProcessor, true)
        this._blurEnabled = true
      }
      // Re-attach to show processed stream locally
      this._reattachLocalVideo()

      if (this.hasBlurBtnTarget) {
        this.blurBtnTarget.classList.toggle("btn--active", this._blurEnabled)
      }
    } catch (error) {
      console.warn("[VideoCall] Background blur not available:", error.message)
    }
  }

  _reattachLocalVideo() {
    const tile = this._findTile(this.room.localParticipant)
    if (!tile) return
    tile.querySelectorAll("video").forEach(v => v.remove())
    this._attachLocalTracks()
  }

  async toggleScreenShare() {
    if (!this.room) return

    // If sharing and bar is hidden, show it instead of toggling
    const bar = document.getElementById("screen-share-bar")
    if (this.room.localParticipant.isScreenShareEnabled && bar && bar.style.display === "none") {
      bar.style.display = "flex"
      this.screenBtnTarget.classList.remove("call-btn--recording")
      return
    }

    try {
      const enabled = this.room.localParticipant.isScreenShareEnabled
      await this.room.localParticipant.setScreenShareEnabled(!enabled)
      this.screenBtnTarget.classList.toggle("btn--active", !enabled)
      this.screenBtnTarget.classList.remove("call-btn--recording")
      this._toggleIconState(this.screenBtnTarget, !enabled)
    } catch (error) {
      console.warn("[VideoCall] Screen share not available:", error.message)
    }
  }

  toggleChat() {
    const panel = this.chatPanelTarget
    const visible = panel.style.display !== "none"
    panel.style.display = visible ? "none" : "flex"
    this.chatBtnTarget.classList.toggle("btn--active", !visible)
    // Close settings if open
    if (!visible) this.settingsPanelTarget.style.display = "none"
  }

  async toggleSettings() {
    const panel = this.settingsPanelTarget
    const visible = panel.style.display !== "none"
    panel.style.display = visible ? "none" : "block"
    if (!visible) await this._populateDevices()
  }

  async switchCamera() {
    if (!this.room) return
    const deviceId = this.cameraSelectTarget.value
    await this.room.switchActiveDevice("videoinput", deviceId)
    this._reattachLocalVideo()
  }

  async switchMic() {
    if (!this.room) return
    const deviceId = this.micSelectTarget.value
    await this.room.switchActiveDevice("audioinput", deviceId)
  }

  async switchSpeaker() {
    if (!this.room) return
    const deviceId = this.speakerSelectTarget.value
    await this.room.switchActiveDevice("audiooutput", deviceId)
  }

  async leave() {
    this._cleanup()

    const token = document.querySelector('meta[name="csrf-token"]').content
    await fetch(this.leaveUrlValue, {
      method: "DELETE",
      headers: { "X-CSRF-Token": token }
    })

    this._showCallEndedScreen()
  }

  // Private

  async _joinRoom() {
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

    this.room.on(RoomEvent.ParticipantConnected, (participant) => {
      this._getOrCreateTile(participant)
      // Show avatar if participant has no camera
      this._checkParticipantCamera(participant)
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

      // Attach tracks from participants already in the room
      this.room.remoteParticipants.forEach((participant) => {
        this._getOrCreateTile(participant)
        participant.trackPublications.forEach((pub) => {
          if (pub.track && pub.isSubscribed) {
            this._attachTrack(pub.track, participant)
          }
        })
        this._checkParticipantCamera(participant)
      })

      if (this.startWithVideoValue) {
        await this.room.localParticipant.enableCameraAndMicrophone()
        this._attachLocalTracks()
        this.cameraBtnTarget.classList.add("btn--active")
        this._toggleIconState(this.cameraBtnTarget, true)
      } else {
        await this.room.localParticipant.setMicrophoneEnabled(true)
        this._toggleAvatar(this.room.localParticipant, true)
        this._toggleIconState(this.cameraBtnTarget, false)
      }
      this.micBtnTarget.classList.add("btn--active")
      this._toggleIconState(this.micBtnTarget, true)
    } catch (error) {
      console.error("[VideoCall] Failed to connect:", error)
    }
  }

  _attachTrack(track, participant) {
    if (!this.hasGridTarget) return

    const isLocal = participant === this.room.localParticipant
    if (isLocal && track.kind === "audio") return

    if (track.source === "screen_share") {
      this._attachScreenShare(track, participant)
      return
    }

    const tile = this._getOrCreateTile(participant)
    const element = track.attach()
    element.dataset.trackSid = track.sid
    tile.appendChild(element)
  }

  _attachScreenShare(track, participant) {
    // Remove existing screen share
    this.gridTarget.querySelector(".call-screen-share")?.remove()

    const container = document.createElement("div")
    container.className = "call-screen-share"
    container.dataset.participantIdentity = participant.identity

    const element = track.attach()
    element.dataset.trackSid = track.sid
    container.appendChild(element)

    const isLocal = participant === this.room.localParticipant

    // Only show bar for remote screen shares
    if (!isLocal) {
      const bar = document.createElement("div")
      bar.className = "call-screen-share__bar"
      bar.id = "screen-share-bar"
      bar.innerHTML = `
        <span class="call-screen-share__dot"></span>
        ${participant.name || participant.identity} is sharing their screen
        <button class="call-screen-share__minimize" id="minimize-bar">&times;</button>
      `
      bar.querySelector("#minimize-bar").addEventListener("click", () => bar.remove())
      container.appendChild(bar)
    }

    this.gridTarget.prepend(container)
    this.gridTarget.classList.add("call-grid--screen-share")
  }

  _detachScreenShare(track) {
    const el = this.gridTarget.querySelector(`[data-track-sid="${track.sid}"]`)
    if (el) {
      el.closest(".call-screen-share")?.remove()
      this.gridTarget.classList.remove("call-grid--screen-share")
    }
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
    // Check if it's a screen share
    const screenEl = this.gridTarget.querySelector(`.call-screen-share [data-track-sid="${track.sid}"]`)
    if (screenEl) {
      screenEl.closest(".call-screen-share")?.remove()
      this.gridTarget.classList.remove("call-grid--screen-share")
      return
    }
    track.detach().forEach(el => el.remove())
  }

  _getOrCreateTile(participant) {
    let tile = this._findTile(participant)
    if (!tile) {
      tile = document.createElement("div")
      const isLocal = this.room && participant === this.room.localParticipant
      tile.className = isLocal ? "call-tile call-tile--local" : "call-tile"
      tile.dataset.participantIdentity = participant.identity

      if (isLocal) {
        tile.style.width = "20rem"
        tile.style.maxWidth = "25vw"
        tile.style.position = "absolute"
        tile.style.bottom = "1.5rem"
        tile.style.right = "1.5rem"
        tile.style.zIndex = "2"
        tile.style.border = "2px solid rgba(255,255,255,0.2)"
        tile.style.boxShadow = "0 2px 12px rgba(0,0,0,0.5)"
      }

      // Avatar placeholder (shown when camera is off)
      const avatar = document.createElement("div")
      avatar.className = "call-tile__avatar"
      avatar.style.display = "none"
      avatar.style.alignItems = "center"
      avatar.style.justifyContent = "center"
      avatar.style.width = "100%"
      avatar.style.height = "100%"
      const avatarSize = isLocal ? 80 : 224
      const avatarImg = document.createElement("img")
      avatarImg.src = this._avatarUrlFor(participant)
      avatarImg.alt = participant.name || participant.identity
      avatarImg.width = avatarSize
      avatarImg.height = avatarSize
      avatarImg.style.width = `${avatarSize}px`
      avatarImg.style.height = `${avatarSize}px`
      avatarImg.style.minWidth = `${avatarSize}px`
      avatarImg.style.minHeight = `${avatarSize}px`
      avatarImg.style.borderRadius = "50%"
      avatarImg.style.objectFit = "cover"
      avatar.appendChild(avatarImg)
      tile.appendChild(avatar)

      const nameTag = document.createElement("span")
      nameTag.className = "call-tile__name"
      nameTag.textContent = participant.name || participant.identity
      tile.appendChild(nameTag)

      this.gridTarget.appendChild(tile)
      this._updateGridLayout()
    }
    return tile
  }

  _avatarUrlFor(participant) {
    const isLocal = this.room && participant === this.room.localParticipant
    if (isLocal && this.hasAvatarUrlValue) {
      return this.avatarUrlValue
    }
    // Read avatar from participant metadata (set server-side in JWT)
    try {
      const meta = JSON.parse(participant.metadata || "{}")
      if (meta.avatar_url) return meta.avatar_url
    } catch (_) {}
    return this.avatarUrlValue
  }

  _checkParticipantCamera(participant) {
    const hasCameraOn = participant.isCameraEnabled
    if (!hasCameraOn) {
      this._toggleAvatar(participant, true)
    }
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

  _startCallStatusPoll() {
    this._statusPollTimer = setInterval(async () => {
      try {
        const response = await fetch(`/rooms/${this.roomIdValue}/call/status`, {
          headers: { "Accept": "application/json" }
        })
        if (response.ok) {
          const data = await response.json()
          if (!data.in_call) {
            clearInterval(this._statusPollTimer)
            this._cleanup()
            this._showCallEndedScreen()
          }
        }
      } catch (_) {}
    }, 10000)
  }

  _toggleIconState(btn, isOn) {
    const iconOn = btn.querySelector(".icon-on")
    const iconOff = btn.querySelector(".icon-off")
    if (iconOn && iconOff) {
      iconOn.style.display = isOn ? "inline-flex" : "none"
      iconOff.style.display = isOn ? "none" : "inline-flex"
    }
  }

  async _populateDevices() {
    const devices = await Room.getLocalDevices("audioinput")
    const videoDevices = await Room.getLocalDevices("videoinput")
    const audioOutputDevices = await Room.getLocalDevices("audiooutput")

    this._fillSelect(this.cameraSelectTarget, videoDevices, "camera")
    this._fillSelect(this.micSelectTarget, devices, "mic")
    this._fillSelect(this.speakerSelectTarget, audioOutputDevices, "speaker")
  }

  _fillSelect(select, devices, key) {
    // Destroy existing TomSelect instance
    if (select.tomselect) select.tomselect.destroy()

    select.innerHTML = ""
    devices.forEach(device => {
      const option = document.createElement("option")
      option.value = device.deviceId
      option.textContent = device.label || `Device ${device.deviceId.slice(0, 8)}`
      select.appendChild(option)
    })

    new TomSelect(select, {
      create: false,
      controlInput: null,
      allowEmptyOption: false
    })
  }

  _removeParticipantTile(participant) {
    this._findTile(participant)?.remove()
    this._updateGridLayout()
  }

  _updateGridLayout() {
    const remoteTiles = this.gridTarget.querySelectorAll(".call-tile:not(.call-tile--local)")
    const count = remoteTiles.length
    if (count <= 1) {
      this.gridTarget.style.gridTemplateColumns = "1fr"
    } else if (count <= 4) {
      this.gridTarget.style.gridTemplateColumns = "repeat(2, 1fr)"
    } else {
      this.gridTarget.style.gridTemplateColumns = "repeat(3, 1fr)"
    }
    // Center last odd tile
    remoteTiles.forEach(tile => tile.style.gridColumn = "")
    if (count > 1 && count % 2 === 1) {
      const lastTile = remoteTiles[remoteTiles.length - 1]
      lastTile.style.gridColumn = "1 / -1"
      lastTile.style.maxWidth = "50%"
      lastTile.style.justifySelf = "center"
    }
  }

  _showCallEndedScreen() {
    this.element.innerHTML = `
      <div style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%;color:white;gap:1.5rem;background:oklch(0.12 0 0)">
        <p style="font-size:1.4rem">Call ended</p>
        <div style="display:flex;gap:1rem">
          <a href="/rooms/${this.roomIdValue}" style="background:white;color:#333;border-radius:2rem;padding:0.6rem 1.5rem;text-decoration:none;font-weight:600;font-size:0.95rem">Back to room</a>
          <button onclick="window.close()" style="background:transparent;border:1px solid white;color:white;border-radius:2rem;padding:0.6rem 1.5rem;cursor:pointer;font-weight:600;font-size:0.95rem">Close tab</button>
        </div>
      </div>
    `
  }

  _cleanup() {
    if (this.room) {
      // Stop all local media tracks to release mic/camera
      this.room.localParticipant.trackPublications.forEach(pub => {
        if (pub.track) {
          pub.track.stop()
          pub.track.detach()
        }
      })
      this.room.disconnect(true)
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
