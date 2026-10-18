import { Controller } from "@hotwired/stimulus"
import { Runtime } from "reactionview"

// Saves one setting when its slider is released, then asks ReActionView to
// re-render the page with it. The simulation keeps running meanwhile.
export default class extends Controller {
  static targets = ["output"]
  static values = { url: String, param: String }

  preview(event) {
    if (this.hasOutputTarget) this.outputTarget.textContent = event.target.value
  }

  async save(event) {
    const body = new FormData()
    body.append(this.paramValue, event.target.value)

    const response = await fetch(this.urlValue, {
      method: "PATCH",
      body,
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      }
    })

    if (response.ok) Runtime.get()?.refresh()
  }
}
