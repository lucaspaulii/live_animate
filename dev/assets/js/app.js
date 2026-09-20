import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/dev"
import topbar from "../vendor/topbar"
import LiveAnimate from "../../../assets/js/live_animate"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const socketConfig = LiveAnimate.config({
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    ...colocatedHooks, 
    ...LiveAnimate.hooks
  }
})

// 2. Initialize the socket with the wrapped config
const liveSocket = new LiveSocket("/live", Socket, socketConfig)

// 3. Initialize global features (Navigation Transitions)
LiveAnimate.init(liveSocket)

// Topbar setup
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// 4. Connect
liveSocket.connect()
window.liveSocket = liveSocket
// Dev-only: expose the lib so the playground's lifecycle harness can inspect
// internal state (e.g. the FLIP-tracking map) to detect leaks. Not needed in
// real apps.
window.LiveAnimate = LiveAnimate

if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    reloader.enableServerLogs()

    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
