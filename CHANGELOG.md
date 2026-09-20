# Changelog

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
