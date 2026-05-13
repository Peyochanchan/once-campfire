import { Controller } from "@hotwired/stimulus"

const STORAGE_PREFIX = "campfire:draft:room:"
const SAVE_DEBOUNCE_MS = 300

export default class extends Controller {
  static targets = ["editor"]
  static values = { roomId: Number }

  connect() {
    this._saveTimer = null
    this._boundSubmitEnd = this._onSubmitEnd.bind(this)
    this.element.addEventListener("turbo:submit-end", this._boundSubmitEnd)
    this._restore()
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this._boundSubmitEnd)
    clearTimeout(this._saveTimer)
  }

  save() {
    clearTimeout(this._saveTimer)
    this._saveTimer = setTimeout(() => this._persist(), SAVE_DEBOUNCE_MS)
  }

  _persist() {
    const editor = this._editor
    if (!editor) return

    const text = editor.getDocument().toString().trim()
    if (text.length === 0) {
      this._clear()
      return
    }

    try {
      localStorage.setItem(this._storageKey, JSON.stringify(editor))
    } catch (_) {}
  }

  _restore() {
    const editor = this._editor
    if (!editor) return
    if (editor.getDocument().toString().trim().length > 0) return

    const stored = this._read()
    if (!stored) return

    try {
      editor.loadJSON(stored)
    } catch (_) {
      this._clear()
    }
  }

  _onSubmitEnd(event) {
    if (event.detail?.success) this._clear()
  }

  _read() {
    try {
      const raw = localStorage.getItem(this._storageKey)
      return raw ? JSON.parse(raw) : null
    } catch (_) {
      return null
    }
  }

  _clear() {
    try { localStorage.removeItem(this._storageKey) } catch (_) {}
  }

  get _editor() {
    return this.hasEditorTarget ? this.editorTarget.editor : null
  }

  get _storageKey() {
    return `${STORAGE_PREFIX}${this.roomIdValue}`
  }
}
