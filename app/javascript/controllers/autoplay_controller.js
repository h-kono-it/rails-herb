import { Controller } from "@hotwired/stimulus"
import { useState } from "reactionview"

// Advances the `step` state on a timer while the `playing` state is true.
//
// After a Turbo visit Stimulus can connect this before ReActionView has read
// the new page. Binding then resolves the previous page's states, so the
// timer would drive a page that is gone and `playingChanged` would never fire
// here. Binding on the next task, once the new page is indexed, avoids that.
// A freshly rendered page always starts with `playing` false, so there is
// nothing to resume on connect.
export default class extends Controller {
  static values = { interval: { type: Number, default: 250 } }

  connect() {
    this.binding = setTimeout(() => {
      this.binding = null
      this.state = useState(this)
    })
  }

  disconnect() {
    clearTimeout(this.binding)
    this.stop()
  }

  playingChanged(playing) {
    playing ? this.start() : this.stop()
  }

  start() {
    this.stop()
    this.timer = setInterval(() => this.state.increment("step"), this.intervalValue)
  }

  stop() {
    clearInterval(this.timer)
    this.timer = null
  }
}
