# LiveAnimate

**Declarative UI animations for Phoenix LiveView — entrance/exit, gestures, springs, and page transitions, straight from HEEx with (almost) no JavaScript.**

**[▶ Live demo](https://live-animate-demo.fly.dev)** · [Documentation](https://hexdocs.pm/live_animate) · [Hex](https://hex.pm/packages/live_animate)

Add one `<.motion>` component to your HEEx and get entrance/exit animations, hover/tap/drag gestures, spring physics, scroll triggers, layout (FLIP) animations, and server-driven page transitions. Animations run on the browser's Web Animations API for GPU-accelerated performance; the Elixir side stays purely declarative.

```heex
<.motion id="hero" animate="slide-up" hover="lift">
  <h1>Hello, world!</h1>
</.motion>
```

## Why LiveAnimate

- **Declarative from HEEx.** Describe the animation on the element — no hand-written JavaScript, no imperative transition code.
- **Built for the LiveView lifecycle.** Exit animations that play *before* the server removes an element, FLIP layout animations that survive stream reflows and reorders, and whole-page transitions you declare on a LiveView with `@transition`.
- **Rich motion out of the box.** Spring physics, velocity-aware drag, staggered lists, scroll/viewport triggers, and more than two dozen presets — plus your own inline keyframes and named variants.
- **No runtime npm dependency.** The animation engine is hand-rolled and ships with the package; setup is one hook and one CSS import.
- **Accessible by default.** Honors `prefers-reduced-motion`, with a per-element opt-out for motion you consider decorative.

### Compared to `JS.transition`

Phoenix ships [`Phoenix.LiveView.JS.transition`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html#transition/1), which toggles CSS classes — you hand-write the keyframes and CSS yourself, and there's no spring physics, gestures, drag, FLIP layout, or page transitions. LiveAnimate gives you all of that declaratively, so most UI motion becomes a preset name instead of a stylesheet plus a JS command.

## Installation

### 1. Add the dependency

```elixir
# mix.exs
def deps do
  [
    {:live_animate, "~> 0.1.0"}
  ]
end
```

### 2. Set up JavaScript

```javascript
// assets/js/app.js
import LiveAnimate from "live_animate"

let liveSocket = new LiveSocket("/live", Socket, {
  ...LiveAnimate.config(),
  hooks: { ...LiveAnimate.hooks },
  params: { _csrf_token: csrfToken }
})

LiveAnimate.init()
```

### 3. Import CSS

```css
/* assets/css/app.css */
@import "../../deps/live_animate/assets/css/live_animate.css";
```

### 4. Import the component

```elixir
# lib/my_app_web.ex
defp html_helpers do
  quote do
    import LiveAnimate
    # ...
  end
end
```

## Quick start

```heex
<%# Fade in on mount %>
<.motion id="hero" animate="fade">
  <h1>Hello, world!</h1>
</.motion>

<%# Hover and tap interactions %>
<.motion id="btn" hover="scale-up" tap="press">
  <button>Click me</button>
</.motion>

<%# Exit animation %>
<.motion id="toast" animate="slide-left" exit="fade">
  <p>Dismissible toast</p>
</.motion>
```

## Available presets

| Preset | Type | Description |
|---|---|---|
| `fade` | entrance/exit | Opacity 0 to 1 |
| `blur` | entrance/exit | Opacity + blur |
| `slide-up` | entrance/exit | Translate Y + fade |
| `slide-down` | entrance/exit | Translate Y + fade |
| `slide-left` | entrance/exit | Translate X + fade |
| `slide-right` | entrance/exit | Translate X + fade |
| `zoom-in` | entrance/exit | Scale 0.8 to 1 + fade |
| `zoom-out` | entrance/exit | Scale 1.2 to 1 + fade |
| `drop` | entrance/exit | Translate Y + scale + fade |
| `flip-x` | entrance/exit | Rotate X 90deg + fade |
| `flip-y` | entrance/exit | Rotate Y 90deg + fade |
| `scale-up` | gesture | Scale to 1.05 |
| `scale-down` | gesture | Scale to 0.95 |
| `press` | gesture | Scale to 0.92 |
| `lift` | gesture | Scale + drop shadow |
| `tilt-left` | gesture | Rotate -3deg |
| `tilt-right` | gesture | Rotate 3deg |
| `shake` | keyframe | Horizontal shake |
| `bounce` | keyframe | Vertical bounce |
| `pulse` | keyframe | Scale pulse |
| `wiggle` | keyframe | Rotational wiggle |
| `spin` | keyframe | Full 360deg rotation |
| `ping` | keyframe | Scale up + fade out |
| `rubber-band` | keyframe | Elastic stretch |
| `float` | keyframe | Gentle vertical bob (pair with `loop: true`) |
| `highlight` | keyframe | Non-displacing attention pulse (ring + tint) |

## Browser support

- **Core animations** (entrance/exit, gestures, springs, keyframes) use the Web Animations API and individual transform properties — supported across current Chromium, Firefox, and Safari.
- **Page transitions** use the [View Transitions API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transitions_API) (Chromium-based browsers and Safari 18+). Where it isn't available, navigation falls back to an instant swap with no error.
- All animations respect the user's **`prefers-reduced-motion`** setting and collapse to instant when it's enabled — override per element with `respect_motion={false}`.

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/live_animate).

## License

MIT - see [LICENSE](LICENSE).
