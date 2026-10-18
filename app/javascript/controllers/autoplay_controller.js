import { Controller } from "@hotwired/stimulus"
import { useState } from "reactionview"

// Advances the `step` state on a timer while the `playing` state is true.
export default class extends Controller {
  static values = { interval: { type: Number, default: 250 } }

  connect() {
    this.state = useState(this)
    if (this.state.get("playing")) this.start()
  }

  disconnect() {
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
