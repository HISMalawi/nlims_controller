import { Controller } from "@hotwired/stimulus"

// An API key secret exists on screen once and is never recoverable, so copying
// it has to be one click and has to say plainly that it worked.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { copied: String }

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.textContent.trim()).then(() => {
      const original = this.buttonTarget.textContent
      this.buttonTarget.textContent = this.copiedValue
      setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
    })
  }
}
