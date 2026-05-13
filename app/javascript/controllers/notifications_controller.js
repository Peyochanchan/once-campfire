import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { pageIsTurboPreview } from "../helpers/turbo_helpers"
import { onNextEventLoopTick } from "../helpers/timing_helpers"
import { getCookie, setCookie } from "../lib/cookie"

export default class extends Controller {
  static values = { subscriptionsUrl: String }
  static targets = [ "notAllowedNotice", "bell", "details" ]
  static classes = [ "attention" ]

  async connect() {
    if (!pageIsTurboPreview()) {
      if (window.notificationsPreviouslyReady) {
        onNextEventLoopTick(() => this.dispatch("ready"))
      } else {
        const firstTimeReady = await this.isEnabled()

        this.#pulseBellButton()

        if (firstTimeReady) {
          onNextEventLoopTick(() => this.dispatch("ready"))
          window.notificationsPreviouslyReady = true
        } else {
          this.#showBellAlert()
        }
      }
    }
  }

  attemptToSubscribe() {
    console.log("[push] attemptToSubscribe", { allowed: this.#allowed, permission: Notification.permission, userActivation: navigator.userActivation?.isActive })
    if (!this.#allowed) {
      this.#revealNotAllowedNotice()
      this.#endFirstRun()
      return
    }

    const permission = Notification.permission

    if (permission === "denied") {
      this.#revealNotAllowedNotice()
      this.#endFirstRun()
      return
    }

    if (permission === "granted") {
      this.#registerAndSubscribe()
      this.#endFirstRun()
      return
    }

    Notification.requestPermission()
      .then(result => {
        console.log("[push] requestPermission result:", result)
        if (result === "granted") {
          return this.#registerAndSubscribe()
        } else if (result === "denied") {
          this.#revealNotAllowedNotice()
        }
      })
      .catch(err => console.error("[push] requestPermission FAILED:", err?.name, err?.message))
      .finally(() => this.#endFirstRun())
  }

  async #registerAndSubscribe() {
    try {
      let registration = await this.#serviceWorkerRegistration
      if (!registration) {
        await this.#registerServiceWorker()
      }
      registration = await navigator.serviceWorker.ready
      console.log("[push] SW active", registration?.scope, registration?.active?.state)
      this.#subscribe(registration)
    } catch (err) {
      console.error("[push] SW register FAILED:", err?.name, err?.message)
    }
  }

  async isEnabled() {
    if (this.#allowed) {
      const registration = await this.#serviceWorkerRegistration
      const existingSubscription = await registration?.pushManager?.getSubscription()

      return Notification.permission == "granted" && registration && existingSubscription
    } else {
      return false
    }
  }

  get #allowed() {
    return navigator.serviceWorker && window.Notification
  }

  get #serviceWorkerRegistration() {
    return navigator.serviceWorker.getRegistration(window.location.origin)
  }

  #registerServiceWorker() {
    return navigator.serviceWorker.register("/service-worker.js")
  }

  #revealNotAllowedNotice() {
    this.notAllowedNoticeTarget.showModal()
    this.#openSingleOption()
  }

  #openSingleOption() {
    const visibleElements = this.detailsTargets.filter(item => !this.#isHidden(item))

    if (visibleElements.length === 1) {
      this.detailsTargets.forEach(item => item.toggleAttribute("open", item === visibleElements[0]))
    }
  }

  #showBellAlert() {
    this.bellTarget.querySelectorAll("img").forEach(img => img.toggleAttribute("hidden"))
  }

  #pulseBellButton() {
    if (!this.#hasSeenFirstRun) {
      this.bellTarget.classList.add(this.attentionClass)
    }
  }

  #endFirstRun() {
    this.bellTarget.classList.remove(this.attentionClass)
    this.#markFirstRunSeen()
  }

  async #subscribe(registration) {
    console.log("[push] subscribe start", { registration, vapidLength: this.#vapidPublicKey?.length })
    registration.pushManager
      .subscribe({ userVisibleOnly: true, applicationServerKey: this.#vapidPublicKey })
      .then(subscription => {
        console.log("[push] subscribe OK", subscription?.endpoint)
        this.#syncPushSubscription(subscription)
        this.dispatch("ready")
      })
      .catch(err => console.error("[push] subscribe FAILED:", err?.name, err?.message, err))
  }

  async #syncPushSubscription(subscription) {
    try {
      const response = await post(this.subscriptionsUrlValue, { body: this.#extractJsonPayloadAsString(subscription), responseKind: "turbo-stream" })
      console.log("[push] sync sub response", response?.statusCode, response?.ok)
      if (!response.ok) subscription.unsubscribe()
    } catch (err) {
      console.error("[push] sync sub FAILED:", err)
    }
  }

  get #vapidPublicKey() {
    const encodedVapidPublicKey = document.querySelector('meta[name="vapid-public-key"]').content
    return this.#urlBase64ToUint8Array(encodedVapidPublicKey)
  }

  get #hasSeenFirstRun() {
    if (this.#isPWA) {
      return getCookie("notifications-pwa-first-run-seen")
    } else {
      return getCookie("notifications-first-run-seen")
    }
  }

  #markFirstRunSeen = (event) => {
    if (this.#isPWA) {
      setCookie("notifications-pwa-first-run-seen", true)
    } else {
      setCookie("notifications-first-run-seen", true)
    }
  }

  #extractJsonPayloadAsString(subscription) {
    const { endpoint, keys: { p256dh, auth } } = subscription.toJSON()
    return JSON.stringify({ push_subscription: { endpoint, p256dh_key: p256dh, auth_key: auth } })
  }

  // VAPID public key comes encoded as base64 but service worker registration needs it as a Uint8Array
  #urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - base64String.length % 4) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")

    const rawData = window.atob(base64)
    const outputArray = new Uint8Array(rawData.length)

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }

    return outputArray
  }

  #isHidden(item) {
    return (item.offsetParent === null)
  }

  get #isPWA() {
    return window.matchMedia("(display-mode: standalone)").matches
  }
}
