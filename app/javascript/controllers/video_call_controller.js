import { Controller } from "@hotwired/stimulus"
import { Room, RoomEvent, createLocalVideoTrack, createLocalAudioTrack } from "livekit-client"
import { BackgroundProcessor } from "@livekit/track-processors"

export default class extends Controller {
  static targets = ["grid", "cameraBtn", "micBtn", "screenBtn", "blurBtn", "settingsBtn", "settingsPanel", "cameraSelect", "micSelect", "speakerSelect", "chatBtn", "chatPanel", "pipBtn", "controlsBar", "prejoinPanel", "prejoinVideo", "prejoinPlaceholder", "prejoinHint", "prejoinCamBtn", "prejoinMicBtn", "prejoinJoinBtn", "prejoinCamSelect", "prejoinMicSelect", "prejoinSpkSelect", "prejoinSpkLabel", "prejoinVu", "prejoinVuFill"]
  static values = {
    token: String,
    url: String,
    roomId: Number,
    leaveUrl: String,
    avatarUrl: String,
    startWithVideo: { type: Boolean, default: true },
    labelEnded: { type: String, default: "Call ended" },
    labelBack: { type: String, default: "Back to room" },
    labelClose: { type: String, default: "Close tab" },
    labelSpotlight: { type: String, default: "Spotlight" },
    labelUnspotlight: { type: String, default: "Remove spotlight" }
  }

  _spotlightIdentity = null
  _prejoinCamEnabled = true
  _prejoinMicEnabled = true
  _prejoinVideoTrack = null
  _prejoinAudioTrack = null
  _devicePrefs = null
  _vuContext = null
  _vuAnalyser = null
  _vuSource = null
  _vuRafId = null

  static DEVICE_PREFS_KEY = "campfire:devices"

  connect() {
    this._boundBeforeUnload = this._beforeUnload.bind(this)
    window.addEventListener("beforeunload", this._boundBeforeUnload)
    this._setupPipSupport()

    if (this.hasTokenValue && this.tokenValue) {
      this._prejoinCamEnabled = this.startWithVideoValue
      this._startPrejoin()
    }
  }

  disconnect() {
    window.removeEventListener("beforeunload", this._boundBeforeUnload)
    clearTimeout(this._controlsTimer)
    clearInterval(this._statusPollTimer)
    this._cleanup()
  }

  _setupPipSupport() {
    if (!this.hasPipBtnTarget) return
    if (!document.pictureInPictureEnabled) this.pipBtnTarget.disabled = true
  }

  async togglePip() {
    if (!document.pictureInPictureEnabled) return

    if (document.pictureInPictureElement) {
      try { await document.exitPictureInPicture() } catch (_) {}
      this.pipBtnTarget?.classList.remove("btn--active")
      return
    }

    const video = this._findVideoForPip()
    if (!video) return

    try {
      video.addEventListener("leavepictureinpicture", () => {
        this.pipBtnTarget?.classList.remove("btn--active")
      }, { once: true })

      await video.requestPictureInPicture()
      this.pipBtnTarget?.classList.add("btn--active")
    } catch (error) {
      console.warn("[VideoCall] PiP request failed:", error.message)
    }
  }

  _findVideoForPip() {
    const spotlight = this.gridTarget.querySelector(".call-tile--spotlight video")
    if (spotlight && spotlight.readyState >= 2) return spotlight

    const screenShare = this.gridTarget.querySelector(".call-screen-share video")
    if (screenShare && screenShare.readyState >= 2) return screenShare

    const remoteVideos = this.gridTarget.querySelectorAll(".call-tile:not(.call-tile--local) video")
    for (const v of remoteVideos) {
      if (v.readyState >= 2 && v.offsetParent !== null) return v
    }
    return null
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
    if (!cameraPub || !cameraPub.track) {
      console.warn("[blur] no camera track to process")
      return
    }

    try {
      if (this._blurEnabled) {
        await cameraPub.track.stopProcessor()
        this._blurEnabled = false
      } else {
        if (!this._blurProcessor) {
          this._blurProcessor = BackgroundProcessor({ mode: "background-blur", blurRadius: 18 })
        }
        await cameraPub.track.setProcessor(this._blurProcessor, true)
        this._blurEnabled = true
      }
      this._reattachLocalVideo()

      if (this.hasBlurBtnTarget) {
        this.blurBtnTarget.classList.toggle("btn--active", this._blurEnabled)
      }
    } catch (error) {
      console.error("[blur] toggle FAILED:", error?.name, error?.message, error)
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
    if (this._devicePrefs) { this._devicePrefs.camId = deviceId; this._saveDevicePrefs() }
  }

  async switchMic() {
    if (!this.room) return
    const deviceId = this.micSelectTarget.value
    await this.room.switchActiveDevice("audioinput", deviceId)
    if (this._devicePrefs) { this._devicePrefs.micId = deviceId; this._saveDevicePrefs() }
  }

  async switchSpeaker() {
    if (!this.room) return
    const deviceId = this.speakerSelectTarget.value
    await this.room.switchActiveDevice("audiooutput", deviceId)
    if (this._devicePrefs) { this._devicePrefs.spkId = deviceId; this._saveDevicePrefs() }
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

  // Prejoin

  async _startPrejoin() {
    this._devicePrefs = this._loadDevicePrefs()

    try {
      this._prejoinVideoTrack = await createLocalVideoTrack(this._devicePrefs.camId ? { deviceId: this._devicePrefs.camId } : undefined)
      this._prejoinVideoTrack.attach(this.prejoinVideoTarget)
    } catch (error) {
      console.warn("[VideoCall] Prejoin camera unavailable:", error?.message)
      this._showPrejoinPlaceholder()
      this._prejoinCamEnabled = false
    }

    try {
      this._prejoinAudioTrack = await createLocalAudioTrack(this._devicePrefs.micId ? { deviceId: this._devicePrefs.micId } : undefined)
    } catch (error) {
      console.warn("[VideoCall] Prejoin microphone unavailable:", error?.message)
      this._prejoinMicEnabled = false
    }

    if (!this._prejoinVideoTrack && !this._prejoinAudioTrack) {
      this.prejoinHintTarget.textContent = this.prejoinHintTarget.dataset.permissionDeniedHint || this.prejoinHintTarget.textContent
    }

    this._updatePrejoinBtnState(this.prejoinCamBtnTarget, this._prejoinCamEnabled)
    this._updatePrejoinBtnState(this.prejoinMicBtnTarget, this._prejoinMicEnabled)

    if (!this._prejoinCamEnabled) this._showPrejoinPlaceholder()

    await this._populatePrejoinDevices()
    this._startVuMeter()
  }

  async _populatePrejoinDevices() {
    const [cams, mics, spks] = await Promise.all([
      Room.getLocalDevices("videoinput").catch(() => []),
      Room.getLocalDevices("audioinput").catch(() => []),
      Room.getLocalDevices("audiooutput").catch(() => [])
    ])

    this._fillSelect(this.prejoinCamSelectTarget, cams, "camera")
    this._fillSelect(this.prejoinMicSelectTarget, mics, "mic")
    this._fillSelect(this.prejoinSpkSelectTarget, spks, "speaker")

    if (this._prejoinVideoTrack?.mediaStreamTrack) {
      const id = this._prejoinVideoTrack.mediaStreamTrack.getSettings().deviceId
      if (id) this.prejoinCamSelectTarget.value = id
    }
    if (this._prejoinAudioTrack?.mediaStreamTrack) {
      const id = this._prejoinAudioTrack.mediaStreamTrack.getSettings().deviceId
      if (id) this.prejoinMicSelectTarget.value = id
    }
    if (this._devicePrefs.spkId && spks.some(d => d.deviceId === this._devicePrefs.spkId)) {
      this.prejoinSpkSelectTarget.value = this._devicePrefs.spkId
    }

    // Hide speaker picker on browsers without setSinkId support (Firefox, Safari mobile)
    const supportsSetSinkId = typeof HTMLMediaElement.prototype.setSinkId === "function"
    if (!supportsSetSinkId || spks.length === 0) this.prejoinSpkLabelTarget.style.display = "none"
  }

  async switchPrejoinCamera() {
    const deviceId = this.prejoinCamSelectTarget.value
    if (!deviceId) return
    this._devicePrefs.camId = deviceId
    this._saveDevicePrefs()

    if (this._prejoinVideoTrack) {
      this._prejoinVideoTrack.detach()
      this._prejoinVideoTrack.stop()
      this._prejoinVideoTrack = null
    }

    try {
      this._prejoinVideoTrack = await createLocalVideoTrack({ deviceId })
      this._prejoinVideoTrack.attach(this.prejoinVideoTarget)
      if (!this._prejoinCamEnabled) this._prejoinVideoTrack.mute()
      this._hidePrejoinPlaceholder()
    } catch (error) {
      console.warn("[VideoCall] switchPrejoinCamera failed:", error?.message)
      this._showPrejoinPlaceholder()
    }
  }

  async switchPrejoinMic() {
    const deviceId = this.prejoinMicSelectTarget.value
    if (!deviceId) return
    this._devicePrefs.micId = deviceId
    this._saveDevicePrefs()

    if (this._prejoinAudioTrack) {
      this._prejoinAudioTrack.stop()
      this._prejoinAudioTrack = null
    }

    try {
      this._prejoinAudioTrack = await createLocalAudioTrack({ deviceId })
      if (!this._prejoinMicEnabled) this._prejoinAudioTrack.mute()
      this._startVuMeter()
    } catch (error) {
      console.warn("[VideoCall] switchPrejoinMic failed:", error?.message)
    }
  }

  switchPrejoinSpeaker() {
    const deviceId = this.prejoinSpkSelectTarget.value
    if (!deviceId) return
    this._devicePrefs.spkId = deviceId
    this._saveDevicePrefs()
  }

  _loadDevicePrefs() {
    try { return JSON.parse(localStorage.getItem(this.constructor.DEVICE_PREFS_KEY)) || {} }
    catch (_) { return {} }
  }

  _saveDevicePrefs() {
    try { localStorage.setItem(this.constructor.DEVICE_PREFS_KEY, JSON.stringify(this._devicePrefs)) }
    catch (_) {}
  }

  _startVuMeter() {
    this._stopVuMeter()
    if (!this._prejoinAudioTrack?.mediaStreamTrack) return
    if (!this.hasPrejoinVuFillTarget) return

    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext
      this._vuContext = new AudioCtx()
      this._vuSource = this._vuContext.createMediaStreamSource(new MediaStream([this._prejoinAudioTrack.mediaStreamTrack]))
      this._vuAnalyser = this._vuContext.createAnalyser()
      this._vuAnalyser.fftSize = 1024
      this._vuAnalyser.smoothingTimeConstant = 0.5
      this._vuSource.connect(this._vuAnalyser)

      const buffer = new Uint8Array(this._vuAnalyser.fftSize)
      const tick = () => {
        if (!this._vuAnalyser) return
        this._vuAnalyser.getByteTimeDomainData(buffer)
        let sumSquares = 0
        for (let i = 0; i < buffer.length; i++) {
          const norm = (buffer[i] - 128) / 128
          sumSquares += norm * norm
        }
        const rms = Math.sqrt(sumSquares / buffer.length)
        const level = this._prejoinMicEnabled ? Math.min(1, rms * 4) : 0
        this.prejoinVuFillTarget.style.inlineSize = `${level * 100}%`
        this._vuRafId = requestAnimationFrame(tick)
      }
      tick()
    } catch (error) {
      console.warn("[VideoCall] VU meter unavailable:", error?.message)
      this._stopVuMeter()
    }
  }

  _stopVuMeter() {
    if (this._vuRafId) { cancelAnimationFrame(this._vuRafId); this._vuRafId = null }
    if (this._vuSource) { try { this._vuSource.disconnect() } catch (_) {} this._vuSource = null }
    if (this._vuAnalyser) { try { this._vuAnalyser.disconnect() } catch (_) {} this._vuAnalyser = null }
    if (this._vuContext) { try { this._vuContext.close() } catch (_) {} this._vuContext = null }
    if (this.hasPrejoinVuFillTarget) this.prejoinVuFillTarget.style.inlineSize = "0%"
  }

  togglePrejoinCamera() {
    if (!this._prejoinVideoTrack) return
    this._prejoinCamEnabled = !this._prejoinCamEnabled
    if (this._prejoinCamEnabled) {
      this._prejoinVideoTrack.unmute()
      this._hidePrejoinPlaceholder()
    } else {
      this._prejoinVideoTrack.mute()
      this._showPrejoinPlaceholder()
    }
    this._updatePrejoinBtnState(this.prejoinCamBtnTarget, this._prejoinCamEnabled)
  }

  togglePrejoinMic() {
    if (!this._prejoinAudioTrack) return
    this._prejoinMicEnabled = !this._prejoinMicEnabled
    if (this._prejoinMicEnabled) {
      this._prejoinAudioTrack.unmute()
    } else {
      this._prejoinAudioTrack.mute()
    }
    this._updatePrejoinBtnState(this.prejoinMicBtnTarget, this._prejoinMicEnabled)
  }

  async joinFromPrejoin() {
    this.prejoinJoinBtnTarget.disabled = true
    this._stopVuMeter()
    if (this._prejoinVideoTrack) this._prejoinVideoTrack.detach()
    await this._joinRoom()
    this._hidePrejoin()
  }

  cancelPrejoin() {
    this._stopVuMeter()
    this._stopPrejoinTracks()
    window.close()
  }

  _showPrejoinPlaceholder() {
    if (!this.hasPrejoinPlaceholderTarget) return
    this.prejoinVideoTarget.style.display = "none"
    this.prejoinPlaceholderTarget.style.display = "flex"
  }

  _hidePrejoinPlaceholder() {
    if (!this.hasPrejoinPlaceholderTarget) return
    this.prejoinVideoTarget.style.display = ""
    this.prejoinPlaceholderTarget.style.display = "none"
  }

  _updatePrejoinBtnState(btn, isOn) {
    if (!btn) return
    btn.classList.toggle("btn--active", isOn)
    this._toggleIconState(btn, isOn)
  }

  _hidePrejoin() {
    this.prejoinPanelTarget.style.display = "none"
    this.gridTarget.style.display = ""
    if (this.hasControlsBarTarget) this.controlsBarTarget.style.display = ""
    this._setupControlsAutoHide()
    this._startCallStatusPoll()
  }

  _stopPrejoinTracks() {
    if (this._prejoinVideoTrack) { this._prejoinVideoTrack.stop(); this._prejoinVideoTrack = null }
    if (this._prejoinAudioTrack) { this._prejoinAudioTrack.stop(); this._prejoinAudioTrack = null }
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

    this.room.on(RoomEvent.LocalTrackUnpublished, (publication) => {
      if (publication.track) {
        this._detachTrack(publication.track)
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
      // Auto-leave if last participant remaining
      if (this.room.remoteParticipants.size === 0) {
        this.leave()
      }
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

      if (this._prejoinVideoTrack) {
        if (this._prejoinCamEnabled) {
          await this.room.localParticipant.publishTrack(this._prejoinVideoTrack, { source: "camera" })
          this._attachLocalTracks()
          this.cameraBtnTarget.classList.add("btn--active")
          this._toggleIconState(this.cameraBtnTarget, true)
        } else {
          this._prejoinVideoTrack.stop()
          this._toggleAvatar(this.room.localParticipant, true)
          this._toggleIconState(this.cameraBtnTarget, false)
        }
        this._prejoinVideoTrack = null
      } else {
        this._toggleAvatar(this.room.localParticipant, true)
        this._toggleIconState(this.cameraBtnTarget, false)
      }

      if (this._prejoinAudioTrack) {
        if (this._prejoinMicEnabled) {
          await this.room.localParticipant.publishTrack(this._prejoinAudioTrack, { source: "microphone" })
          this.micBtnTarget.classList.add("btn--active")
          this._toggleIconState(this.micBtnTarget, true)
        } else {
          this._prejoinAudioTrack.stop()
          this._toggleIconState(this.micBtnTarget, false)
        }
        this._prejoinAudioTrack = null
      } else {
        this._toggleIconState(this.micBtnTarget, false)
      }

      if (this._devicePrefs?.spkId) {
        try { await this.room.switchActiveDevice("audiooutput", this._devicePrefs.spkId) } catch (_) {}
      }
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
    // Screen share takes over the main area — clear any active spotlight
    if (this._spotlightIdentity) {
      this._spotlightIdentity = null
      this.gridTarget.classList.remove("call-grid--spotlight")
      this.gridTarget.querySelectorAll(".call-tile--spotlight").forEach(t => t.classList.remove("call-tile--spotlight"))
    }

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

      if (!isLocal) {
        const pinBtn = document.createElement("button")
        pinBtn.type = "button"
        pinBtn.className = "call-tile__pin"
        pinBtn.title = this.labelSpotlightValue
        pinBtn.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 17v5"/><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/></svg>`
        pinBtn.addEventListener("click", (event) => {
          event.stopPropagation()
          this._toggleSpotlight(participant)
        })
        tile.appendChild(pinBtn)
      }

      this.gridTarget.appendChild(tile)
      this._updateGridLayout()
    }
    return tile
  }

  _toggleSpotlight(participant) {
    if (this._spotlightIdentity === participant.identity) {
      this._spotlightIdentity = null
    } else {
      this._spotlightIdentity = participant.identity
    }
    this._applySpotlight()
  }

  _applySpotlight() {
    const tiles = this.gridTarget.querySelectorAll(".call-tile:not(.call-tile--local)")
    tiles.forEach(tile => {
      const isSpotlighted = tile.dataset.participantIdentity === this._spotlightIdentity
      tile.classList.toggle("call-tile--spotlight", isSpotlighted)
      const pin = tile.querySelector(".call-tile__pin")
      if (pin) pin.title = isSpotlighted ? this.labelUnspotlightValue : this.labelSpotlightValue
    })

    if (this._spotlightIdentity) {
      this.gridTarget.classList.add("call-grid--spotlight")
      const spotlightTile = this.gridTarget.querySelector(".call-tile--spotlight")
      if (spotlightTile) this.gridTarget.prepend(spotlightTile)
      this.gridTarget.style.gridTemplateColumns = ""
    } else {
      this.gridTarget.classList.remove("call-grid--spotlight")
      this._updateGridLayout()
    }
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

    const prefs = this._devicePrefs || {}
    if (prefs.camId && videoDevices.some(d => d.deviceId === prefs.camId)) this.cameraSelectTarget.value = prefs.camId
    if (prefs.micId && devices.some(d => d.deviceId === prefs.micId)) this.micSelectTarget.value = prefs.micId
    if (prefs.spkId && audioOutputDevices.some(d => d.deviceId === prefs.spkId)) this.speakerSelectTarget.value = prefs.spkId
  }

  _fillSelect(select, devices, key) {
    select.innerHTML = ""
    devices.forEach(device => {
      const option = document.createElement("option")
      option.value = device.deviceId
      option.textContent = device.label || `Device ${device.deviceId.slice(0, 8)}`
      select.appendChild(option)
    })
  }

  _removeParticipantTile(participant) {
    if (this._spotlightIdentity === participant.identity) {
      this._spotlightIdentity = null
      this.gridTarget.classList.remove("call-grid--spotlight")
    }
    this._findTile(participant)?.remove()
    this._updateGridLayout()
  }

  _updateGridLayout() {
    if (this._spotlightIdentity) return

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
        <p style="font-size:1.4rem">${this.labelEndedValue}</p>
        <div style="display:flex;gap:1rem">
          <a href="/rooms/${this.roomIdValue}" style="background:white;color:#333;border-radius:2rem;padding:0.6rem 1.5rem;text-decoration:none;font-weight:600;font-size:0.95rem">${this.labelBackValue}</a>
          <button onclick="window.close()" style="background:transparent;border:1px solid white;color:white;border-radius:2rem;padding:0.6rem 1.5rem;cursor:pointer;font-weight:600;font-size:0.95rem">${this.labelCloseValue}</button>
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
