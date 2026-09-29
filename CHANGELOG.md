# Changelog

## 0.1.3

### Fixed

- **Drag conflicted with touch scrolling.** On touch devices a drag could fight
  the browser's native scroll: a horizontal swipe would move a few pixels and
  snap back "stuck", and a card that had been re-rendered stopped dragging
  altogether. The gesture is now claimed on `pointerdown` and leaves scroll-vs-
  drag arbitration to the `touch-action` CSS property (the browser's job), rather
  than deferring the claim behind a movement threshold and re-deciding direction
  in script — which let the browser latch a scroll it then tore away via
  `pointercancel`. `touch-action` is also re-asserted after a LiveView re-render
  (morphdom strips the inline style), so a patched element keeps arbitrating
  correctly. The movement threshold now only gates when the drag becomes visible
  and whether a release counts as a drag (so a tap on a draggable stays a tap).

- **`in_view` with `repeat: true` could loop forever.** The same feedback trap
  the `scroll` trigger fixed in 0.1.1: an `in_view` animation that moves the
  element via `translate` (e.g. `slide-up`) oscillated in→out→in at a specific
  scroll point, because `IntersectionObserver` measures the transformed box. The
  repeat path now uses the same Schmitt trigger — enter on an inner band, exit
  only past a hysteresis gap wider than any preset's translate. (`repeat: false`
  was never affected: it plays once and stops observing.)

### Documentation

- README now covers **drag** and **page transitions** — the `use LiveAnimate` +
  `@transition` API, the per-page timing map, and `apply_to` (navigate vs. also
  patch) — with runnable examples.
- Added a layout note to the drag docs: draggable/sliding elements that travel
  past the viewport edge expand the page's horizontal scroll — bound them with
  `constraints`, or clip overflow at the page level.

## 0.1.2

### Fixed

- **Drag could get stuck when pointer capture was lost.** A drag holds the pointer
  via `setPointerCapture`; if the browser released that capture mid-drag without a
  `pointerup` reaching the element — e.g. the button was released outside the page
  (over browser chrome/off-screen), the window lost focus, a native gesture took
  over, or a LiveView re-render/reconnect re-attached the node — the drag never
  ended: the element stayed stuck to the cursor and never snapped back. A
  `lostpointercapture` handler now ends the drag (snap-back / settle) on any such
  capture loss. Normal releases are unaffected (they clear drag state before
  releasing capture, so the follow-on event is a no-op).

## 0.1.1

### Fixed

- **Scroll trigger infinite loop.** A `scroll` animation that moves the element
  via `translate` (e.g. `slide-up`) could oscillate forever at a specific scroll
  point: because `IntersectionObserver` measures the transformed box, playing the
  "out" animation at the trigger edge shoved the element back across the boundary,
  re-firing "in", then "out" again. The trigger now uses a Schmitt trigger — enter
  on an inner band, exit only past a looser outer band, with a fixed hysteresis gap
  wider than any preset's translate — so the animation's own motion can never
  re-cross the opposite threshold.

## 0.1.0

Initial release.

### Core

- `<.motion>` component with a declarative animation lifecycle: `animate`,
  `exit`, `hover`, `tap`, `drag`, `in_view`, and `scroll`.
- Animations run on the Web Animations API (WAAPI) for GPU-accelerated
  performance; the Elixir side stays purely declarative.
- Animations compose via the **individual transform properties**
  (`translate`/`scale`/`rotate`) instead of the `transform` shorthand, so a
  hover `scale`, a drag `translate`, and a FLIP `translate` don't clobber
  each other.

### Presets

- Entrance/exit: `fade`, `blur`, `slide-up`, `slide-down`, `slide-left`,
  `slide-right`, `zoom-in`, `zoom-out`, `drop`, `flip-x`, `flip-y`.
- Gesture: `scale-up`, `scale-down`, `press`, `lift`, `tilt-left`, `tilt-right`.
- Keyframe/attention: `shake`, `bounce`, `pulse`, `wiggle`, `spin`, `ping`,
  `rubber-band`, `float`, `highlight`.
- Custom inline `keyframes` and user-defined variants via
  `LiveAnimate.config({ variants: { ... } })`.

### Transitions

- Per-animation `:transition` config — spring physics
  (`stiffness`/`damping`/`mass`, velocity-aware) or tween easing (CSS keyword,
  `cubic-bezier(...)`, or a 4-element control-point list).
- Global default spring via `LiveAnimate.config({ spring: { ... } })`.

### Gestures

- `hover`/`tap` via pointer events (touch-guarded).
- `drag` with axis locking, bounds (`constraints`), elastic overscroll, and a
  velocity-aware spring snap-back that carries the fling's momentum — or
  `snap_back: false` to stay where dropped. Emits `phx-drag-end` to the server.

### Triggers & lists

- `in_view` and `scroll` triggers backed by `IntersectionObserver` (with
  `repeat`), so there's no per-scroll layout work on the main thread.
- `stagger` offsets each child's animation; computed per mount-batch, so stream
  appends don't inherit a runaway delay.

### LiveView lifecycle integration

- **Exit animations** play before LiveView removes an element, via the
  `phx-remove` transition binding.
- **FLIP layout animations** (`layout`) animate elements smoothly through stream
  reflows and reorders; id-reuse safe.
- **Server-driven page transitions**: `use LiveAnimate` + `@transition` drives
  the View Transitions API on navigation. Presets `fade`, `blur`, `slide-left`,
  `slide-right`, `slide-up`, `slide-down`; optional per-transition `duration`
  and `easing`; `apply_to: :navigate` (default) or `:all` to also transition
  `live_patch` updates. Falls back to the default crossfade where the View
  Transitions API is unavailable.

### Accessibility

- Honors `prefers-reduced-motion` by default (animations collapse to instant).
- Per-element `respect_motion={false}` opt-out for decorative animations, and a
  global `LiveAnimate.config({ respectMotion: false })` default (with per-element
  `respect_motion={true}` to opt back in).
