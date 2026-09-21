import { Presets } from "./presets";

const isObject = (val) => val !== null && typeof val === "object" && !Array.isArray(val);

// Identity/rest value for each animatable property, used to build the "natural
// state" keyframe opposite an effect preset. Because presets use the individual
// transform properties (`translate`/`scale`/`rotate`), each resets on its own
// channel — so the natural state of a `scale` effect leaves `translate`
// untouched, letting an in-flight drag/FLIP translate survive.
const IDENTITY_VALUES = {
  opacity: "1",
  translate: "0px 0px",
  scale: "1",
  rotate: "0deg",
  filter: "none"
};

// Build identity/rest values for each property in an effect preset.
const naturalStyles = (effectStyles) => {
  const rest = {};
  for (const prop of Object.keys(effectStyles)) {
    rest[prop] = IDENTITY_VALUES[prop] ?? "none";
  }
  return rest;
};

const TRANSITION_TIMEOUT = 5000;

const _prefersReducedMotion = () =>
  window.matchMedia("(prefers-reduced-motion: reduce)").matches;

// A LiveView per-event loading class (phx-click-loading, phx-change-loading,
// phx-keyup-loading, …). Every one ends in "loading"; the phx state classes
// (phx-error, phx-connected, phx-no-feedback, …) do not, and are left alone.
const _isPhxLoadingClass = (c) => /^phx-.*loading$/.test(c);

// Parse a computed `translate` value ("none" | "<x>" | "<x> <y>" | "<x> <y> <z>",
// always in px from getComputedStyle) into [x, y]. Used to re-grab a drag from an
// element's current on-screen position mid snap-back.
const _parseTranslate = (val) => {
  if (!val || val === "none") return [0, 0];
  const p = val.split(/\s+/);
  return [parseFloat(p[0]) || 0, parseFloat(p[1] ?? "0") || 0];
};

// The set of a class string's tokens with phx-*loading tokens removed, sorted,
// for order-insensitive comparison. Two class strings that differ only in
// loading classes produce the same result.
const _meaningfulClasses = (cls) =>
  (cls || "")
    .split(/\s+/)
    .filter((c) => c && !_isPhxLoadingClass(c))
    .sort()
    .join(" ");

// ─── Page transition presets (View Transitions API) ───
// Each preset defines how the destination page's root crosses IN and how the
// previous page's root exits (OUT). We emit two @keyframes plus animation-name
// on the ::view-transition-old/new(root) pseudo-elements. Duration and easing
// come from the existing `::view-transition-*(*)` rule in live_animate.css
// (var(--lm-duration-default) / var(--lm-spring)), so only the keyframes are
// swapped here.
const PAGE_TRANSITIONS = {
  "fade": { out: { to: { opacity: 0 } }, in: { from: { opacity: 0 } } },
  "blur": {
    out: { to: { opacity: 0, filter: "blur(6px)" } },
    in: { from: { opacity: 0, filter: "blur(6px)" } }
  },
  "slide-left": {
    out: { to: { opacity: 0, transform: "translateX(-30px)" } },
    in: { from: { opacity: 0, transform: "translateX(30px)" } }
  },
  "slide-right": {
    out: { to: { opacity: 0, transform: "translateX(30px)" } },
    in: { from: { opacity: 0, transform: "translateX(-30px)" } }
  },
  "slide-up": {
    out: { to: { opacity: 0, transform: "translateY(-30px)" } },
    in: { from: { opacity: 0, transform: "translateY(30px)" } }
  },
  "slide-down": {
    out: { to: { opacity: 0, transform: "translateY(30px)" } },
    in: { from: { opacity: 0, transform: "translateY(-30px)" } }
  }
  // Note: no scale-based page transition. Scaling the rasterized page snapshot
  // resamples it (shimmers, esp. on text), so page transitions stay on
  // opacity/translate/filter. For element-level zoom use the `zoom-in`/`zoom-out`
  // presets, which animate the real element, not a snapshot.
};

const _kebab = (s) => s.replace(/[A-Z]/g, (m) => "-" + m.toLowerCase());
const _keyframeStop = (obj) =>
  Object.entries(obj).map(([k, v]) => `${_kebab(k)}: ${v}`).join("; ");

// Resolve a page-transition easing value to a CSS timing function. Accepts CSS
// keywords, snake_case aliases (ease_out), a cubic-bezier() string, or a
// 4-element [x1,y1,x2,y2] array.
function _cssEasing(ease) {
  if (Array.isArray(ease) && ease.length === 4) return `cubic-bezier(${ease.join(", ")})`;
  if (typeof ease === "string" && ease.startsWith("cubic-bezier(")) return ease;
  return TWEEN_EASINGS[ease] || ease;
}

// Build the CSS (two @keyframes + two pseudo rules) for a named page transition,
// or null if the name isn't a known preset (caller falls back to the default
// browser crossfade). `duration` (ms number or CSS time string) and `easing`
// are optional per-transition overrides; when omitted the pseudo-elements
// inherit the global ::view-transition-*(*) defaults (var(--lm-duration-default)
// / var(--lm-spring)).
function _pageTransitionCSS(name, duration, easing) {
  const t = PAGE_TRANSITIONS[name];
  if (!t) return null;
  const outName = `lm-vt-${name}-out`;
  const inName = `lm-vt-${name}-in`;
  const kf = (kfName, spec) => {
    const stops = [];
    if (spec.from) stops.push(`from { ${_keyframeStop(spec.from)} }`);
    if (spec.to) stops.push(`to { ${_keyframeStop(spec.to)} }`);
    return `@keyframes ${kfName} { ${stops.join(" ")} }`;
  };
  let timing = "";
  if (duration != null) timing += ` animation-duration: ${typeof duration === "number" ? duration + "ms" : duration};`;
  if (easing) timing += ` animation-timing-function: ${_cssEasing(easing)};`;
  // The UA default cross-fades the old/new snapshots with `mix-blend-mode:
  // plus-lighter` inside an isolated group. That blend flickers when both layers
  // are *transformed* while fading (most visibly on scale/zoom). Opting out —
  // `isolation: auto` on the pair + `mix-blend-mode: normal` — makes the new
  // snapshot composite plainly over the old, removing the flicker. Harmless for
  // fade/slide. The group timing is synced so a custom duration/easing doesn't
  // desync the group morph from the old/new animations.
  return [
    kf(outName, t.out),
    kf(inName, t.in),
    `::view-transition-image-pair(root) { isolation: auto; }`,
    `::view-transition-group(root) {${timing} }`,
    `::view-transition-old(root) { animation-name: ${outName}; mix-blend-mode: normal;${timing} }`,
    `::view-transition-new(root) { animation-name: ${inName}; mix-blend-mode: normal;${timing} }`
  ].join("\n");
}

// ─── Spring Easing Generator ───

const _springCache = new Map();

/**
 * Simulate a damped spring and return a linear() CSS easing string
 * plus the natural settling duration in milliseconds.
 *
 * Models displacement y(t) from equilibrium with y(0) = `distance` and
 * y'(0) = `velocity`, then emits progress toward the target as
 * easing(t) = 1 - y(t)/distance. With the defaults (velocity 0, distance 1)
 * this reduces exactly to the classic rest-to-target spring:
 *   x(t) = 1 - e^(-ζω₀t)(cos(ωd·t) + (ζ/√(1-ζ²))sin(ωd·t))
 * A non-zero `velocity` bends the curve at t=0 so the motion carries momentum
 * (used for drag-release hand-off). `velocity`/`distance` are in the caller's
 * units per second / units (e.g. px/s and px); only their ratio and signs
 * shape the curve.
 *
 * ω₀ = √(k/m), ζ = c/(2√(km)), ωd = ω₀√(1-ζ²)
 */
function generateSpringEasing(stiffness = 100, damping = 10, mass = 1, samples = 50, velocity = 0, distance = 1) {
  // Only the rest case (velocity 0) is cached — release curves vary per fling.
  const cacheable = velocity === 0;
  const key = `${stiffness}:${damping}:${mass}`;
  if (cacheable && _springCache.has(key)) return _springCache.get(key);

  const w0 = Math.sqrt(stiffness / mass);
  const zeta = damping / (2 * Math.sqrt(stiffness * mass));
  const D = distance || 1; // guard against divide-by-zero
  const v0 = velocity;

  // Time for envelope to decay below threshold
  const epsilon = 0.001;
  let settleTime;
  if (zeta <= 0.001) {
    settleTime = 5; // Nearly undamped — cap
  } else if (zeta < 1) {
    settleTime = -Math.log(epsilon) / (zeta * w0);
  } else {
    // Critically/over-damped: slower mode dominates
    const slowRate = w0 * (zeta - Math.sqrt(Math.max(zeta * zeta - 1, 0)));
    settleTime = slowRate > 0 ? -Math.log(epsilon) / slowRate : -Math.log(epsilon) / w0;
  }
  settleTime = Math.min(settleTime, 10);

  const points = [];
  for (let i = 0; i <= samples; i++) {
    const t = (i / samples) * settleTime;
    let yOverD; // y(t)/distance — displacement remaining, as a fraction

    if (zeta < 1) {
      // Underdamped — oscillates before settling
      const wd = w0 * Math.sqrt(1 - zeta * zeta);
      const b = (v0 + zeta * w0 * D) / (wd * D); // sin coefficient (v0=0 ⇒ ζω₀/ωd)
      yOverD = Math.exp(-zeta * w0 * t) * (Math.cos(wd * t) + b * Math.sin(wd * t));
    } else if (zeta === 1) {
      // Critically damped — fastest non-oscillating settle
      yOverD = Math.exp(-w0 * t) * (1 + (v0 / D + w0) * t);
    } else {
      // Overdamped — slow exponential approach
      const sq = Math.sqrt(zeta * zeta - 1);
      const s1 = w0 * (-zeta + sq);
      const s2 = w0 * (-zeta - sq);
      const c1 = (v0 - s2 * D) / ((s1 - s2) * D); // C1/distance
      const c2 = 1 - c1; // C2/distance (C1 + C2 = distance)
      yOverD = c1 * Math.exp(s1 * t) + c2 * Math.exp(s2 * t);
    }

    // progress = 1 - remaining; overshoot yields values outside [0,1],
    // which linear() applies as over/undershoot of the interpolated value.
    points.push(Math.round((1 - yOverD) * 1000) / 1000);
  }

  // Clamp endpoints so the motion starts exactly at the source and lands
  // exactly on the target regardless of sampling/settle-time approximation.
  points[0] = 0;
  points[points.length - 1] = 1;

  const result = {
    easing: `linear(${points.join(", ")})`,
    duration: Math.round(settleTime * 1000)
  };

  if (cacheable) _springCache.set(key, result);
  return result;
}

// ─── Tween Easing ───

const TWEEN_EASINGS = {
  "linear": "linear",
  "ease": "ease",
  "ease-in": "ease-in",
  "ease-out": "ease-out",
  "ease-in-out": "ease-in-out",
  // snake_case (Elixir convention)
  "ease_in": "ease-in",
  "ease_out": "ease-out",
  "ease_in_out": "ease-in-out",
  // camelCase (common JS convention)
  "easeIn": "ease-in",
  "easeOut": "ease-out",
  "easeInOut": "ease-in-out",
};

function _getDefaultEasing() {
  return getComputedStyle(document.documentElement)
    .getPropertyValue('--lm-spring').trim() || "ease-out";
}

/**
 * Resolve a transition config into { easing, duration }.
 * `duration` is null when the transition doesn't specify one (caller uses its own default).
 *
 * Supports:
 *   { type: "spring", stiffness: 200, damping: 20, mass: 1 }
 *   { type: "tween", ease: "ease-in-out" }
 *   { type: "tween", ease: [0.42, 0, 0.58, 1] }  → cubic-bezier()
 *   { type: "tween", ease: "cubic-bezier(...)" }   → passthrough
 */
function _resolveTransition(transition) {
  if (!transition) {
    // Use global default spring if configured, otherwise CSS variable
    if (LiveAnimate._defaultSpring) {
      const { stiffness, damping, mass } = LiveAnimate._defaultSpring;
      const spring = generateSpringEasing(stiffness, damping, mass);
      return { easing: spring.easing, duration: null };
    }
    return { easing: _getDefaultEasing(), duration: null };
  }

  if (transition.type === "spring") {
    const stiffness = transition.stiffness ?? LiveAnimate._defaultSpring?.stiffness ?? 100;
    const damping = transition.damping ?? LiveAnimate._defaultSpring?.damping ?? 10;
    const mass = transition.mass ?? LiveAnimate._defaultSpring?.mass ?? 1;
    const spring = generateSpringEasing(stiffness, damping, mass);
    return {
      easing: spring.easing,
      duration: transition.duration ?? spring.duration
    };
  }

  if (transition.type === "tween") {
    let easing;
    const ease = transition.ease;
    if (Array.isArray(ease) && ease.length === 4) {
      easing = `cubic-bezier(${ease.join(", ")})`;
    } else if (typeof ease === "string" && ease.startsWith("cubic-bezier(")) {
      easing = ease;
    } else {
      easing = TWEEN_EASINGS[ease] || "ease-in-out";
    }
    return { easing, duration: transition.duration ?? null };
  }

  // Unknown type — treat duration as override, fall back to default easing
  return { easing: _getDefaultEasing(), duration: transition.duration ?? null };
}

const injectStyles = () => {
  if (document.getElementById("live-animate-styles")) return;

  const style = document.createElement("style");
  style.id = "live-animate-styles";
  style.innerHTML = `
    .lm-animating-exit {
      pointer-events: none;
    }
  `;
  document.head.appendChild(style);
};

const LiveAnimateHook = {
  mounted() {
    this.config = JSON.parse(this.el.dataset.lmConfig || "{}");
    // Per-element reduced-motion policy. `respect_motion: false` opts a
    // decorative animation out of `prefers-reduced-motion` (it always plays);
    // `true` forces the element to honor it even if the global default is off;
    // omitted → inherit the global default (`LiveAnimate._respectMotion`, itself
    // true unless set via `config({ respectMotion: false })`).
    this._respectMotion = this.config.respect_motion ?? LiveAnimate._respectMotion ?? true;
    this._cleanups = [];
    this._observers = [];
    this._layoutEntry = null;
    // NOTE: we deliberately do NOT auto-assign `view-transition-name` here. Only
    // elements given an explicit `name` (rendered server-side as an inline
    // `view-transition-name` style) participate as their own view-transition
    // group. Auto-naming every element would lift all of them out of `(root)`
    // during a page navigation, so they'd crossfade in place while the custom
    // page transition (which targets `(root)`) slides/blurs — an incoherent
    // result on any page with both `@transition` and many `<.motion>` elements.
    // Per-element shared-element morphing is a deliberate v2.0 feature, opt-in
    // via `name`.

    // Register for FLIP BEFORE entrance animation so stored position is clean.
    // Keep our own reference to the entry (tracking no longer depends on id).
    if (this.config.layout) {
      this._layoutEntry = LiveAnimate._trackLayout(this.el);
    }

    // Compute stagger delay from this element's position within its *mount
    // batch* — the set of elements added in the same LiveView patch — NOT its
    // absolute sibling index. Absolute index breaks stream append: a node
    // appended into a 10-item list would be sibling #10 and inherit a
    // 10*stagger delay, even though it's the only new element. Batch-relative
    // indexing gives every fresh insert (prepend or append) delay 0, while a
    // multi-item batch (initial render, reset) still staggers 0,1,2,…
    const stagger = this.config.stagger || 0;
    this._staggerDelay = 0;
    if (stagger > 0) {
      this._staggerDelay = LiveAnimate._nextStaggerIndex() * stagger;
    }

    if (!this.config.in_view && !this.config.scroll) {
      const animConfig = this.config.animate || {};
      const loop = animConfig.loop;
      const interval = animConfig.interval;
      const staggerOpts = this._staggerDelay > 0 ? { delay: (animConfig.delay ?? 0) + this._staggerDelay } : {};

      // Whether the entrance resolves to a keyframe array (custom `keyframes`, or
      // an array preset like "ping"/"shake"). Array effects settle to rest via
      // fill:"none" and must NOT be committed to inline style (see the commit block
      // below) — committing would re-freeze an off-rest final frame.
      const entranceEffect = animConfig.keyframes
        || (typeof animConfig.action === "string" ? getStylesForPreset(animConfig.action) : null);
      const entranceIsArray = Array.isArray(entranceEffect);

      if (loop && interval > 0) {
        // Manual loop with pause between iterations
        const playLoop = () => {
          const anim = this._runAnimation("animate", "in", staggerOpts);
          if (anim) {
            anim.finished.then(() => {
              this._loopTimer = setTimeout(playLoop, interval);
            }).catch(() => {});
          }
        };
        playLoop();
      } else {
        const entranceAnim = this._runAnimation("animate", "in", {
          ...(loop ? { iterations: Infinity } : {}),
          ...staggerOpts
        });
        // Once entrance settles, remove the fill:forwards hold so WAAPI
        // releases control of transform/opacity. Without this, inline style
        // changes (e.g. from drag) are overridden by the stale animation layer.
        //
        // This applies only to OBJECT-form entrances (effect → natural), which
        // run with fill:"both" and hold their final rest frame. Keyframe-ARRAY
        // entrances run with fill:"none" (see _runAnimation): they self-release to
        // the underlying rest state, so there's no fill layer to release and
        // nothing to commit — committing would instead re-freeze an off-rest final
        // frame (e.g. `ping` ends at opacity:0). Hence `!entranceIsArray`.
        //
        // NOTE (morphdom interaction): commitStyles writes the final values to
        // the element's inline `style`. LiveView's patcher (morphdom) strips any
        // attribute the server's node doesn't have, and <.motion> renders no
        // `style` unless `name` is set — so a later server re-render of THIS
        // element removes these committed styles. That is harmless: every
        // object-form entrance settles at the identity/rest state (naturalStyles
        // → IDENTITY_VALUES: opacity 1, translate 0, scale 1, …), which equals the
        // CSS default, so the element reverts to the exact same values — no visible
        // change.
        if (entranceAnim && !loop) {
          entranceAnim.finished.then(() => {
            if (!entranceIsArray) {
              if (entranceAnim.commitStyles) {
                entranceAnim.commitStyles();
              } else {
                // Fallback for browsers without commitStyles (Safari <16.4):
                // manually apply the final keyframe values as inline styles
                const computed = getComputedStyle(this.el);
                const effect = entranceAnim.effect;
                if (effect) {
                  const keyframes = effect.getKeyframes();
                  const last = keyframes[keyframes.length - 1];
                  for (const prop of Object.keys(last)) {
                    if (prop === "offset" || prop === "easing" || prop === "composite") continue;
                    this.el.style[prop] = computed[prop];
                  }
                }
              }
              entranceAnim.cancel();
            }

            if (this._layoutEntry) {
              this._layoutEntry.pos = LiveAnimate._absPos(this.el);
            }
          }).catch(() => {});
        }
      }
    }
    this._setupExit();
    this._setupEvents();
  },

  updated() {
    // Re-parse config so event-time reads stay current. Hover/tap and the
    // animation side (action/duration/easing) read `this.config` live, so those
    // DO reflect a server patch. What does NOT re-initialize here is the one-time
    // setup in `_setupDrag`/`_setupScroll`/`_setupInView`: their params (axis,
    // constraints, elastic, rootMargin, amount, repeat) and the listener/observer
    // wiring are captured in `mounted()`. So changing a gesture's config — or
    // enabling a gesture that wasn't present at mount — via a patch won't take
    // effect on an already-mounted element (re-initializing would need per-gesture
    // teardown, and `_cleanups`/`_observers` are flat). To reconfigure a gesture
    // dynamically, vary the element's `id` (e.g. id={"card-#{@mode}"}) to force a
    // remount.
    this.config = JSON.parse(this.el.dataset.lmConfig || "{}");

    // Re-assert a stay-put drag position (`snap_back: false`). A server re-render
    // of this element strips the inline translate we set on drop (morphdom syncs
    // it to the server's node, which has none), which would otherwise snap it
    // back to origin while the drag state still thinks it's here. Snap-back drags
    // clear the offset, so this is a no-op for the common gesture case.
    if (this._dragOffset && (this._dragOffset.x || this._dragOffset.y)) {
      this.el.style.translate = `${this._dragOffset.x}px ${this._dragOffset.y}px`;
    }
  },

  // No `reconnected()` handler — deliberately. On a LiveView socket reconnect,
  // the join patch preserves existing DOM nodes, so hook instances survive and
  // only `reconnected()` fires; `mounted()` does NOT re-run. Entrance animations
  // live in `mounted()`, so they play once and are not replayed on reconnect —
  // the element is already settled. Do NOT add a `reconnected()` that re-runs the
  // entrance: on a flaky network that would re-trigger every element's entrance
  // on every reconnect (a visible "replay storm"). Genuinely new elements in a
  // post-reconnect patch still mount and animate normally, as intended.

  destroyed() {
    if (this._loopTimer) clearTimeout(this._loopTimer);
    this._cleanups.forEach(fn => fn());
    this._cleanups = [];
    this._observers.forEach(obs => obs.disconnect());
    this._observers = [];

    // Unregister from FLIP tracking (by our own entry, so a same-id element that
    // replaced us in a reset keeps its tracking).
    LiveAnimate._untrackLayout(this._layoutEntry);
  },

  _addListener(target, event, handler, options) {
    target.addEventListener(event, handler, options);
    this._cleanups.push(() => target.removeEventListener(event, handler, options));
  },

  // Whether this element should collapse its animations to instant. Honors the
  // user's `prefers-reduced-motion` setting UNLESS this element (or the global
  // config) opted out via `respect_motion: false`.
  _reduce() {
    return _prefersReducedMotion() && this._respectMotion !== false;
  },

  // configKey: which config entry to use ("animate", "exit", "in_view", "scroll")
  // direction: "in" = effect → natural, "out" = natural → effect
  _runAnimation(configKey, direction = "in", options = {}) {
    const config = this.config[configKey];
    if (!config) return;

    // Custom keyframes take priority over preset names
    let effectStyles;
    if (config.keyframes) {
      effectStyles = config.keyframes;
    } else {
      const presetName = config?.action || config;
      if (!presetName || typeof presetName !== "string") return;
      effectStyles = getStylesForPreset(presetName);
    }
    if (!effectStyles) return;

    const resolved = _resolveTransition(config?.transition);
    const reduce = this._reduce();
    const duration = reduce ? 0 : (options.duration ?? resolved.duration ?? config?.duration);
    const delay = reduce ? 0 : (options.delay ?? config?.delay ?? 0);
    const iterations = options.iterations ?? 1;
    // "both" (not just "forwards") so the initial keyframe is applied during any
    // `delay` window too. Without backwards fill, a delayed/staggered entrance
    // shows the element in its final state until the delay elapses, then snaps to
    // the hidden keyframe and animates — a visible flash (e.g. a staggered item
    // appended to a list). Post-finish behavior is unchanged (forwards fill still
    // holds the final state until commitStyles releases it).
    const fill = iterations === Infinity ? "none" : "both";
    const easing = resolved.easing;

    // Keyframe arrays play as-is for "in", reversed for "out".
    //
    // A keyframe preset is a transient *effect* that returns to rest, so as an
    // entrance/effect ("in") it must NOT hold its final frame: a preset whose last
    // frame is off-rest (e.g. `ping` ends at opacity:0, scale:1.5) would otherwise
    // stay stuck in that state after finishing — invisible for a one-shot, and for
    // the whole gap between iterations of an interval loop. fill:"none" lets it
    // settle back to the underlying rest state. As an *exit* ("out") the opposite
    // is required: it must hold the final frame until LiveView removes the node, or
    // the element snaps back visible mid-removal — so keep fill:"both" there.
    if (Array.isArray(effectStyles)) {
      const keyframes = direction === "out" ? [...effectStyles].reverse() : effectStyles;
      const arrayFill = direction === "out" ? "both" : "none";
      return this.el.animate(keyframes, { duration, delay, easing, fill: arrayFill, iterations });
    }

    const natural = naturalStyles(effectStyles);
    let keyframes;
    if (direction === "in") {
      keyframes = [effectStyles, natural];
    } else if (options.implicit) {
      // Single keyframe: WAAPI uses the current visual state (including
      // hover/gesture effects) as the implicit starting point.
      keyframes = [effectStyles];
    } else {
      keyframes = [natural, effectStyles];
    }

    return this.el.animate(keyframes, { duration, delay, easing, fill, iterations });
  },

  _setupExit() {
    if (!this.config.exit) return;
    if (!this.liveSocket?.binding) return;

    const removeAttr = this.liveSocket.binding("remove");
    const exitResolved = _resolveTransition(this.config.exit.transition);
    const duration = exitResolved.duration ?? this.config.exit.duration;

    // Add safety margin so Phoenix doesn't remove the element before animation
    // finishes. Under reduced motion the exit runs at 0ms (see `_reduce`), so
    // there's nothing to wait for — holding the element (and blocking the patch,
    // since the transition is `blocking: "exit"`) for the full duration would
    // just add lag for exactly the users who opted out of motion. Remove ~instantly
    // instead. (`_reduce()` is read here at mount; a mid-session OS toggle isn't
    // re-evaluated, which is fine.)
    const safeTime = this._reduce() ? 0 : duration + 50;

    this.el.setAttribute(removeAttr, JSON.stringify([
      ["transition", {
        time: safeTime,
        transition: [["lm-animating-exit"], [], []],
        blocking: "exit"
      }]
    ]));

    // Popping the exiting element out of flow (position:fixed) lets its
    // siblings reflow to fill the gap — desirable only for `layout` elements,
    // which then FLIP-animate into the vacated space. Without layout, keeping
    // the element in flow preserves its box so the container doesn't collapse
    // (e.g. to h-0) before the exit animation has finished playing.
    const popLayout = !!this.config.layout;

    // Detect exit class via MutationObserver (fires as microtask, before paint).
    const exitObserver = new MutationObserver(() => {
      if (this.el.classList.contains("lm-animating-exit")) {
        exitObserver.disconnect();

        // Remove gesture listeners so hover/tap can't create new
        // animations during exit (pointer-events:none handles most
        // cases, but cleanup is safer).
        this._cleanups.forEach(fn => fn());
        this._cleanups = [];

        if (popLayout) {
          // Measure the position now, at the moment of exit, so the fixed
          // clone lands exactly where the element currently sits. FLIP and
          // stream reflows move elements client-side without firing the hook's
          // `updated()`, so any position captured earlier would be stale (the
          // clone would appear at the element's old grid cell). For FLIP-tracked
          // elements `_measureExitPos` reads the stored natural position, which
          // is race-free even when several siblings exit in the same batch.
          const { width, height, pageLeft, pageTop } = this._measureExitPos();
          const targetLeft = pageLeft - window.scrollX;
          const targetTop = pageTop - window.scrollY;

          // Take element out of flow so siblings immediately reflow.
          Object.assign(this.el.style, {
            position: "fixed",
            boxSizing: "border-box",
            left: `${targetLeft}px`,
            top: `${targetTop}px`,
            width: `${width}px`,
            height: `${height}px`,
            margin: "0",
            zIndex: "10"
          });

          // A transformed / filtered / contained ancestor (e.g. a `layout`
          // section that is mid-FLIP) becomes the containing block for a
          // position:fixed element, so the coords above land relative to it
          // instead of the viewport — the clone jumps to the section's corner.
          // Measure where it actually landed and correct so it stays put.
          const landed = this.el.getBoundingClientRect();
          const dx = targetLeft - landed.left;
          const dy = targetTop - landed.top;
          if (dx || dy) {
            this.el.style.left = `${targetLeft + dx}px`;
            this.el.style.top = `${targetTop + dy}px`;
          }
        }

        this._runAnimation("exit", "out", { implicit: true });
      }
    });
    exitObserver.observe(this.el, { attributes: true, attributeFilter: ["class"] });
    this._observers.push(exitObserver);
  },

  _measureExitPos() {
    const width = this.el.offsetWidth;
    const height = this.el.offsetHeight;

    // Prefer the FLIP-tracked natural position for layout elements. We read this
    // element's OWN entry (not a lookup by id), so a same-id element re-added
    // during a reset can't hand us its position instead. The FLIP observer keeps
    // `entry.pos` current as siblings reflow and always stores an untransformed
    // page-absolute top-left, so it stays accurate through stream/layout changes
    // and reading it avoids forcing a reflow at exit time (which would race with
    // other siblings popping out of flow in the same batch).
    const tracked = this._layoutEntry;
    if (tracked && tracked.pos) {
      return { width, height, pageLeft: tracked.pos.left, pageTop: tracked.pos.top };
    }

    const rect = this.el.getBoundingClientRect();
    return {
      width,
      height,
      pageLeft: rect.left + (rect.width - width) / 2 + window.scrollX,
      pageTop: rect.top + (rect.height - height) / 2 + window.scrollY
    };
  },

  _animateGesture(configKey, reverse) {
    const config = this.config[configKey];
    const presetName = config?.action || config;
    if (!presetName || typeof presetName !== "string") return;

    const activeStyles = getStylesForPreset(presetName);
    if (!activeStyles) return;

    const resolved = _resolveTransition(config?.transition);
    const duration = this._reduce() ? 0 : (resolved.duration ?? config?.duration);
    const easing = resolved.easing;

    // Keyframe arrays: play forward on activate, skip reverse
    // (most keyframe presets end at their starting position)
    if (Array.isArray(activeStyles)) {
      if (reverse) return;
      return this.el.animate(activeStyles, { duration, easing });
    }

    const restStyles = naturalStyles(activeStyles);
    const keyframes = reverse ? [activeStyles, restStyles] : [restStyles, activeStyles];
    return this.el.animate(keyframes, { duration, easing, fill: "forwards" });
  },

  _setupEvents() {
    if (this.config.hover) {
      // Hover is a mouse/pen affordance. Guard against touch: a tap fires
      // pointerenter but no matching pointerleave until the pointer next
      // interacts elsewhere, so an unguarded touch would leave the hover state
      // stuck on. Mouse and pen (which have real hover) still work.
      this._addListener(this.el, "pointerenter", (e) => {
        if (e.pointerType === "touch") return;
        this._animateGesture("hover", false);
      });
      this._addListener(this.el, "pointerleave", (e) => {
        if (e.pointerType === "touch") return;
        this._animateGesture("hover", true);
      });
    }
    if (this.config.tap) {
      // Press works on mouse, touch, and pen. Activate on pointerdown on the
      // element; release on pointerup/pointercancel observed on `window`, so
      // lifting the pointer *outside* the element — or a cancel from a scroll
      // gesture — still clears the pressed state instead of leaving it stuck.
      let pressed = false;
      this._addListener(this.el, "pointerdown", (e) => {
        if (e.button !== 0) return; // primary pointer/button only
        pressed = true;
        this._animateGesture("tap", false);
      });
      const release = () => {
        if (!pressed) return;
        pressed = false;
        this._animateGesture("tap", true);
      };
      this._addListener(window, "pointerup", release);
      this._addListener(window, "pointercancel", release);
    }

    if (this.config.in_view) this._setupInView();
    if (this.config.drag) this._setupDrag();
    if (this.config.scroll) this._setupScroll();
  },

  _setupInView() {
    const inViewConfig = this.config.in_view;
    const repeat = isObject(inViewConfig) ? inViewConfig.repeat : false;
    const amount = isObject(inViewConfig) ? inViewConfig.amount : 0.1;
    const staggerOpts = this._staggerDelay > 0
      ? { delay: (inViewConfig?.delay ?? 0) + this._staggerDelay }
      : {};
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this._runAnimation("in_view", "in", staggerOpts);
          if (!repeat) observer.unobserve(this.el);
        } else if (repeat) {
          this._runAnimation("in_view", "out");
        }
      });
    }, { threshold: amount || 0.1 });

    observer.observe(this.el);
    this._observers.push(observer);
  },

  _setupDrag() {
    const dragConfig = isObject(this.config.drag) ? this.config.drag : {};
    const axis = dragConfig.axis || null; // "x", "y", or null (both)
    const constraints = dragConfig.constraints || null; // { top, bottom, left, right }
    const elastic = dragConfig.elastic ?? 0.35; // 0 = hard clamp, 1 = fully elastic
    const snapBack = dragConfig.snap_back ?? true; // false = stay where dropped

    let isDragging = false;
    let activePointerId = null; // the one pointer that owns the active drag
    let startX, startY;
    let currentX = 0;
    let currentY = 0;
    let prevPosition;
    let prevZIndex;
    const mountedAt = performance.now();

    // Pointer velocity (px/s), lightly smoothed, sampled from pointermove.
    // Fed into the spring on release so the snap-back carries the fling's momentum.
    let velX = 0;
    let velY = 0;
    let lastMoveX = 0;
    let lastMoveY = 0;
    let lastMoveT = 0;

    // Rubber-band: beyond the boundary, movement is dampened by elastic factor
    const clampAxis = (value, min, max) => {
      if (min == null && max == null) return value;
      const lo = min ?? -Infinity;
      const hi = max ?? Infinity;
      if (value < lo) return lo + (value - lo) * elastic;
      if (value > hi) return hi + (value - hi) * elastic;
      return value;
    };

    // Hard clamp (no elastic) — where a stay-put drop settles within constraints.
    const hardClamp = (value, min, max) => {
      const lo = min ?? -Infinity;
      const hi = max ?? Infinity;
      return Math.min(hi, Math.max(lo, value));
    };

    this.el.style.cursor = "grab";
    this.el.style.userSelect = "none";
    this.el.style.webkitUserSelect = "none";
    this.el.style.touchAction = axis === "x" ? "pan-y" : axis === "y" ? "pan-x" : "none";

    // Cancel only animations that hold the `translate` channel — a running
    // animation wins over inline styles in the cascade, so any translate
    // animation (entrance slide, FLIP, snap-back) must be cleared for
    // style.translate to take effect. Animations on other channels (a hover
    // `scale`, say) are left alone so they compose with the drag.
    const cancelTranslateAnims = () => {
      this.el.getAnimations().forEach(a => {
        const keyframes = a.effect?.getKeyframes?.() || [];
        if (keyframes.some(k => "translate" in k)) a.cancel();
      });
    };

    const beginDrag = (e) => {
      // One drag at a time. Without this, an overlapping pointerdown (e.g. a
      // second finger on touch) runs beginDrag again and captures the ALREADY-
      // dragging inline styles as `prevPosition`/`prevZIndex` — which then get
      // restored permanently on release, leaving the element stuck at
      // position:relative / z-index:9999.
      if (isDragging) return;

      // If a translate animation is mid-flight (a snap-back from a previous
      // release), adopt its current on-screen position so a re-grab continues
      // from there instead of teleporting to the origin when we cancel it below.
      const midFlight = this.el.getAnimations().some(
        (a) => a.playState === "running" &&
          (a.effect?.getKeyframes?.() || []).some((k) => "translate" in k)
      );
      if (midFlight) {
        const [cx, cy] = _parseTranslate(getComputedStyle(this.el).translate);
        currentX = cx;
        currentY = cy;
        this.el.style.translate = `${cx}px ${cy}px`;
      }

      this.el.setPointerCapture(e.pointerId);
      activePointerId = e.pointerId;
      isDragging = true;
      prevPosition = this.el.style.position;
      prevZIndex = this.el.style.zIndex;
      this.el.style.position = "relative";
      this.el.style.cursor = "grabbing";
      this.el.style.zIndex = "9999";

      cancelTranslateAnims();

      startX = e.clientX - currentX;
      startY = e.clientY - currentY;

      // Seed velocity tracking so the first move computes a sane dt.
      velX = 0;
      velY = 0;
      lastMoveX = currentX;
      lastMoveY = currentY;
      lastMoveT = performance.now();
    };

    const onMove = (e) => {
      if (!isDragging) {
        // Auto-resume: if this element was just mounted (LiveView replaced the
        // node mid-drag via positional DOM patching) and the pointer is still
        // held down, resume the drag on this new node.
        if (e.buttons === 1 && performance.now() - mountedAt < 500) {
          beginDrag(e);
        } else {
          return;
        }
      }
      // Ignore other pointers while a drag is in progress (multitouch): only the
      // pointer that started the drag drives it.
      if (e.pointerId !== activePointerId) return;
      e.preventDefault();

      // Kill any translate animations that appeared after drag started (e.g.
      // entrance slides from LiveView DOM patches mid-drag). WAAPI animations
      // override inline styles, so they must be removed for style.translate
      // to take effect.
      cancelTranslateAnims();

      let rawX = e.clientX - startX;
      let rawY = e.clientY - startY;

      // Axis lock
      if (axis === "x") rawY = 0;
      if (axis === "y") rawX = 0;

      // Apply constraints with elastic overscroll
      if (constraints) {
        rawX = clampAxis(rawX, constraints.left, constraints.right);
        rawY = clampAxis(rawY, constraints.top, constraints.bottom);
      }

      currentX = rawX;
      currentY = rawY;

      // Sample velocity (px/s) with a light low-pass so a single jittery frame
      // doesn't dominate the release. dt is clamped to avoid spikes on the first
      // move or after a stall.
      const now = performance.now();
      const dt = now - lastMoveT;
      if (dt > 0) {
        const instVX = ((currentX - lastMoveX) / dt) * 1000;
        const instVY = ((currentY - lastMoveY) / dt) * 1000;
        velX = 0.8 * instVX + 0.2 * velX;
        velY = 0.8 * instVY + 0.2 * velY;
        lastMoveX = currentX;
        lastMoveY = currentY;
        lastMoveT = now;
      }

      this.el.style.translate = `${currentX}px ${currentY}px`;
    };

    const onStart = (e) => {
      if (e.button !== 0) return; // only primary button
      e.preventDefault();
      beginDrag(e);
    };

    const onEnd = (e) => {
      // Only the drag-owning pointer ends the drag; a different pointer's
      // up/cancel (multitouch) is ignored so it can't cut the gesture short or
      // release a capture it never held.
      if (!isDragging || e.pointerId !== activePointerId) return;
      this.el.releasePointerCapture(e.pointerId);
      activePointerId = null;
      isDragging = false;
      this.el.style.cursor = "grab";

      const fromX = currentX;
      const fromY = currentY;

      // Release velocity — zeroed if the pointer stalled before lifting, so a
      // deliberate "place" doesn't get an unwanted fling.
      const stale = performance.now() - lastMoveT > 100;
      const relVX = stale ? 0 : velX;
      const relVY = stale ? 0 : velY;

      const transition = dragConfig.transition;

      // What `phx-drag-end` reports. Default (snap-back): the release offset, so a
      // gesture handler sees how far you dragged (e.g. swipe-to-dismiss). Stay-put
      // overrides it below with the clamped resting position — where the element
      // actually ends up, not the elastic-overshot release point.
      let dropX = fromX;
      let dropY = fromY;

      if (!snapBack) {
        // Stay where dropped, settling any elastic overshoot back to the hard
        // constraint bound (with no constraints it just holds the release position).
        const restX = constraints ? hardClamp(fromX, constraints.left, constraints.right) : fromX;
        const restY = constraints ? hardClamp(fromY, constraints.top, constraints.bottom) : fromY;
        currentX = restX;
        currentY = restY;
        dropX = restX;
        dropY = restY;
        this.el.style.translate = `${restX}px ${restY}px`;
        // Remember it so `updated()` can re-assert it: a server re-render strips
        // this inline translate (morphdom), which would otherwise snap the element
        // back to origin while the drag state still thinks it's here.
        this._dragOffset = { x: restX, y: restY };

        if (!this._reduce() && Math.hypot(fromX - restX, fromY - restY) >= 0.5) {
          const settle = generateSpringEasing(300, 26, 1);
          this.el.animate(
            [{ translate: `${fromX}px ${fromY}px` }, { translate: `${restX}px ${restY}px` }],
            { duration: settle.duration, easing: settle.easing }
          );
        }
      } else {
        // Snap back to origin.
        this.el.style.translate = "";
        currentX = 0;
        currentY = 0;
        this._dragOffset = null; // back at origin — nothing to re-assert

        const from = [{ translate: `${fromX}px ${fromY}px` }, { translate: "0px 0px" }];
        const D = Math.hypot(fromX, fromY);

        if (this._reduce() || D < 0.5) {
          // Nothing meaningful to animate — the element is already reset to origin.
        } else if (transition && transition.type === "tween") {
          // Explicit tween: fixed easing/duration, no velocity hand-off.
          const resolved = _resolveTransition(transition);
          this.el.animate(from, {
            duration: resolved.duration ?? 300,
            easing: resolved.easing
          });
        } else {
          // Spring snap-back that carries the fling's momentum. Project the pointer
          // velocity onto the release→origin line — the straight path the snap-back
          // travels — and feed it into the spring as its initial velocity.
          const v0 = (relVX * fromX + relVY * fromY) / D;
          // Drag gets its own snappy default (≈0.5s, a hint of overshoot) rather
          // than the page's global entrance spring, which is typically soft and
          // would make a snap-back feel floaty. An explicit drag.transition spring
          // overrides it.
          const sp = (transition && transition.type === "spring")
            ? { stiffness: transition.stiffness ?? 300, damping: transition.damping ?? 26, mass: transition.mass ?? 1 }
            : { stiffness: 300, damping: 26, mass: 1 };
          const spring = generateSpringEasing(sp.stiffness, sp.damping, sp.mass, 50, v0, D);
          this.el.animate(from, {
            duration: transition?.duration ?? spring.duration,
            easing: spring.easing
          });
        }
      }

      this.el.style.zIndex = prevZIndex;
      this.el.style.position = prevPosition;

      // Push drag-end event to server if configured
      const dragEndEvent = this.el.getAttribute("phx-drag-end");
      if (dragEndEvent) {
        this.pushEvent(dragEndEvent, { x: dropX, y: dropY, id: this.el.id });
      }
    };

    // Prevent native drag (e.g. dragging selected text) which fires
    // pointercancel and kills our gesture mid-drag.
    this._addListener(this.el, "dragstart", (e) => e.preventDefault());

    // Pointer events + capture: all events route to el during drag,
    // preventing native text-drag from stealing the gesture.
    this._addListener(this.el, "pointerdown", onStart);
    this._addListener(this.el, "pointermove", onMove);
    this._addListener(this.el, "pointerup", onEnd);
    this._addListener(this.el, "pointercancel", onEnd);
  },

  _setupScroll() {
    const scrollConfig = this.config.scroll;
    // Re-trigger in/out on every crossing by default (scroll is a scrub-style
    // trigger); repeat:false plays "in" once and stops.
    const repeat = isObject(scrollConfig) ? (scrollConfig.repeat ?? true) : true;

    // Binary in/out trigger via IntersectionObserver — no per-scroll-event
    // getBoundingClientRect on the main thread (the old approach forced a
    // layout read on every scroll tick, the exact jank this library exists to
    // avoid).
    //
    // FEEDBACK-LOOP TRAP: the scroll animation moves the element via `translate`
    // (slide-up shifts it 30px), and IntersectionObserver measures the element's
    // *transformed* box. A single trigger band therefore oscillates forever at the
    // band edge: playing "out" shoves the element back across the boundary → "in"
    // → back out → "in"… (the "specific scroll point" infinite loop). The cure is a
    // Schmitt trigger — enter on an inner band, exit only once the element is past a
    // looser outer band, with a fixed px gap (HYSTERESIS) wider than any animation
    // displacement so the element's own motion can never re-cross the opposite
    // threshold. Margins are px (not %) so the gap is viewport-independent; both
    // bands are rebuilt on resize since rootMargin is fixed at construction.
    const HYSTERESIS = 60; // px gap between enter/exit bands; exceeds preset translates
    let inside = false;
    let enterObs = null;
    let exitObs = null;

    const teardown = () => {
      enterObs?.disconnect();
      exitObs?.disconnect();
      window.removeEventListener("resize", build);
    };

    const build = () => {
      enterObs?.disconnect();
      exitObs?.disconnect();
      // Inner band ≈ central 80% (matches the old -10% feel on desktop), but never
      // tighter than HYSTERESIS so the gap below is always exactly HYSTERESIS.
      const inset = Math.max(window.innerHeight * 0.10, HYSTERESIS);
      const exitInset = inset - HYSTERESIS;
      const enterMargin = `-${inset}px 0px -${inset}px 0px`;
      const exitMargin = `-${exitInset}px 0px -${exitInset}px 0px`;

      enterObs = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting && !inside) {
            inside = true;
            this._runAnimation("scroll", "in");
          }
        });
      }, { rootMargin: enterMargin, threshold: 0 });

      exitObs = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (!entry.isIntersecting && inside) {
            inside = false;
            this._runAnimation("scroll", "out");
            if (!repeat) teardown();
          }
        });
      }, { rootMargin: exitMargin, threshold: 0 });

      enterObs.observe(this.el);
      exitObs.observe(this.el);
    };

    build();
    window.addEventListener("resize", build);
    // destroyed() calls .disconnect() on every entry — route it through teardown so
    // both observers and the resize listener are cleaned up.
    this._observers.push({ disconnect: teardown });
  }
};

/**
 * LiveAnimate — declarative animations for Phoenix LiveView.
 *
 * @property {{ LiveAnimate: object }} hooks - Hook object to spread into LiveSocket's `hooks` option.
 */
const LiveAnimate = {
  hooks: { LiveAnimate: LiveAnimateHook },

  /** @private Global default spring params (set via config({ spring: { ... } })). */
  _defaultSpring: null,

  /** @private Global reduced-motion default. `false` (set via config({ respectMotion: false }))
   * makes animations ignore `prefers-reduced-motion` unless an element sets `respect_motion: true`. */
  _respectMotion: true,

  /** @private User-defined variants (merged over built-in presets). */
  _userVariants: {},

  // FLIP: persistent position tracking
  // Stores { el, rect } for every layout-enabled element
  // A Set of tracking entries, NOT a Map keyed by id. Keying by id breaks when
  // two elements share an id (e.g. a stream reset re-adds an id while the old
  // element is still exiting): the entries would clobber each other, corrupting
  // the exiting element's measured position and the surviving element's tracking.
  // Each hook holds a direct reference to its own entry instead, so id reuse — or
  // a missing id — never crosses wires.
  _layoutElements: new Set(),
  _flipScheduled: false,

  // Stagger batching: hooks that mount in the same LiveView patch run their
  // `mounted()` synchronously in one JS task, before microtasks flush. We hand
  // out an incrementing index per task and reset it on the next microtask, so
  // every batch of simultaneously-mounted elements is numbered from 0 —
  // independent of how many siblings already exist in the DOM.
  _staggerIndex: 0,
  _staggerBatchScheduled: false,
  _nextStaggerIndex() {
    if (!this._staggerBatchScheduled) {
      this._staggerBatchScheduled = true;
      this._staggerIndex = 0;
      queueMicrotask(() => { this._staggerBatchScheduled = false; });
    }
    return this._staggerIndex++;
  },

  // Store page-absolute coords (viewport + scroll) so scroll drift
  // between storage and check doesn't produce false deltas.
  _absPos(el) {
    const r = el.getBoundingClientRect();
    return { left: r.left + window.scrollX, top: r.top + window.scrollY };
  },

  _trackLayout(el) {
    const entry = {
      el,
      pos: this._absPos(el),
      flipAnim: null
    };
    this._layoutElements.add(entry);
    // Return the entry so the hook can hold its own reference (see _layoutElements).
    return entry;
  },

  _untrackLayout(entry) {
    if (entry) this._layoutElements.delete(entry);
  },

  _checkFlip() {
    // Self-heal: never let a stuck navigation flag disable FLIP forever. If
    // `_isNavigating` has outlived the transition timeout (a page-loading-stop
    // that never fired, or a browser without the View Transitions API where no
    // timeout is scheduled), clear it here so layout animations resume.
    if (this._isNavigating && performance.now() - (this._navStartedAt || 0) > TRANSITION_TIMEOUT) {
      this._isNavigating = false;
    }
    if (this._flipScheduled || this._isNavigating) return;
    this._flipScheduled = true;

    // Use microtask instead of rAF so FLIP runs before the browser paints
    // the post-removal layout. rAF can be deferred to the next frame,
    // causing a 1-frame jump before FLIP catches the position change.
    //
    // Split into phases so nested layout elements (a FLIP-tracked section that
    // itself contains FLIP-tracked children) don't double-move: every in-flight
    // transform is cleared BEFORE any "last" position is measured, otherwise a
    // parent's translate would offset a child's measured rect and the child
    // would animate to compensate for movement that isn't really there.
    queueMicrotask(() => {
      this._flipScheduled = false;

      // Phase 1 — pick eligible elements and capture each "first" (pre-change)
      // position while any in-flight FLIP transforms are still applied, so a
      // mid-flight element redirects from where it currently appears.
      const pending = [];
      this._layoutElements.forEach((entry) => {
        const el = entry.el;
        if (!el.isConnected || el.classList.contains("lm-animating-exit")) return;

        // Skip elements with running entrance animations — their rect is
        // distorted by WAAPI transforms (e.g. scale(0.5) from zoom-in).
        // Position will be captured correctly on the next check.
        const hasRunningEntrance = el.getAnimations()
          .some(a => a !== entry.flipAnim && a.playState === "running");
        if (hasRunningEntrance) return;

        // If a previous FLIP is mid-flight, use the current visual position
        // as "First" so the animation redirects smoothly instead of snapping.
        const first = (entry.flipAnim && entry.flipAnim.playState === "running")
          ? this._absPos(el)
          : entry.pos;

        pending.push({ entry, el, first });
      });

      // Phase 2 — clear every in-flight FLIP transform so the "last"
      // measurements below are taken against clean, untransformed layout.
      for (const { entry } of pending) {
        if (entry.flipAnim) {
          entry.flipAnim.cancel();
          entry.flipAnim = null;
        }
      }

      // Phase 3 — measure clean post-change positions.
      for (const p of pending) {
        p.last = this._absPos(p.el);
      }

      // Phase 4 — animate each element from its old position to its new one.
      for (const { entry, el, first, last } of pending) {
        const dx = first.left - last.left;
        const dy = first.top - last.top;
        entry.pos = last;

        if (dx === 0 && dy === 0) continue;

        // Animate the `translate` channel (not the `transform` shorthand) so a
        // concurrent hover/tap `scale` on the same element isn't clobbered.
        entry.flipAnim = el.animate([
          { translate: `${dx}px ${dy}px` },
          { translate: "0px 0px" }
        ], {
          // FLIP has no per-element hook context here (it iterates the global
          // tracking set), so it follows the global respect-motion default.
          duration: (_prefersReducedMotion() && this._respectMotion !== false) ? 0 : 300,
          easing: "cubic-bezier(0.175, 0.885, 0.32, 1.1)"
        });
      }
    });
  },

  /**
   * Returns a config object to spread into your LiveSocket constructor.
   *
   * Accepts an optional object with `spring` (default spring physics),
   * `variants` (custom animation presets), and any extra LiveSocket config.
   *
   * @param {object} [userConfig={}]
   * @param {{ stiffness?: number, damping?: number, mass?: number }} [userConfig.spring]
   * @param {Record<string, object | object[]>} [userConfig.variants]
   * @param {boolean} [userConfig.respectMotion] Set `false` to make animations ignore
   *   `prefers-reduced-motion` globally (per-element `respect_motion: true` still opts back in).
   * @returns {object} Config object to spread into LiveSocket options.
   */
  config(userConfig = {}) {
    if (userConfig.spring) {
      this._defaultSpring = userConfig.spring;
    }
    if (userConfig.variants) {
      Object.assign(this._userVariants, userConfig.variants);
    }
    if (userConfig.respectMotion === false) {
      this._respectMotion = false;
    }

    const { spring, variants, respectMotion, ...socketConfig } = userConfig;
    return {
      ...socketConfig,
      onBeforeElUpdated(fromEl, toEl) {
        if (userConfig.onBeforeElUpdated) return userConfig.onBeforeElUpdated(fromEl, toEl);
        return true;
      },
      onBeforeElDeleted(el) {
        // Block removal while exit animation is playing
        if (el.classList && el.classList.contains("lm-animating-exit")) return false;

        if (userConfig.onBeforeElDeleted) return userConfig.onBeforeElDeleted(el);
      }
    };
  },

  /**
   * Initializes LiveAnimate. Call once after creating your LiveSocket.
   *
   * Sets up exit animation styles, navigation view transitions, and
   * the MutationObserver for FLIP layout animations.
   */
  init() {
    // Idempotent: a second call (e.g. init() invoked twice in app.js) would
    // otherwise double-bind the window navigation listeners and the body
    // MutationObserver, starting two view transitions per navigation and running
    // FLIP checks twice. Guard so extra calls are no-ops.
    if (this._initialized) return;
    this._initialized = true;

    injectStyles();
    this._isNavigating = false;
    this._navStartedAt = 0;
    this._pageTransitionApplyTo = "navigate";
    this._setupNavigationTransitions();
    this._setupLayoutObserver();
  },

  _setupLayoutObserver() {
    const observer = new MutationObserver((mutations) => {
      const significantChange = mutations.some(m => {
        if (m.type === "childList") return true;
        if (m.type === "attributes" && m.attributeName === "class") {
          // LiveView toggles a `phx-*loading` class on the acting element for
          // every event round-trip (click/change/keyup/…). Those don't affect
          // layout, so treating them as FLIP triggers would force a reflow of
          // every tracked element on every event. Fire FLIP only when the class
          // change touched something OTHER than a phx-*loading class — so genuine
          // class-driven layout shifts (including phx state classes like
          // phx-error / phx-no-feedback / phx-disconnected, which can move
          // things) still animate.
          // getAttribute (not .className) so SVG elements' class works too.
          const now = m.target.getAttribute ? m.target.getAttribute("class") : null;
          return _meaningfulClasses(m.oldValue) !== _meaningfulClasses(now);
        }
        return false;
      });

      if (significantChange && this._layoutElements.size > 0) {
        this._checkFlip();
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["class"],
      attributeOldValue: true
    });
  },

  // Inject (or clear) the CSS that overrides the root view-transition animation
  // for the current navigation. Called when a page announces its transition via
  // the `lm:page-transition` server event, and reset to the default crossfade at
  // the start of each redirect.
  _applyPageTransitionStyle(transition) {
    const styleId = "lm-page-transition";
    // Accept either "slide-left" or { preset, duration, easing, apply_to }.
    const spec = typeof transition === "string" ? { preset: transition } : (transition || {});
    // Remember whether the current page opted patches into transitions. Reset to
    // "navigate" whenever there's no active transition (e.g. on redirect), so a
    // previous page's `apply_to: :all` can't leak into a plain destination.
    this._pageTransitionApplyTo = spec.apply_to || "navigate";
    const css = spec.preset ? _pageTransitionCSS(spec.preset, spec.duration, spec.easing) : null;
    let style = document.getElementById(styleId);
    if (!css) {
      if (style) style.remove(); // fall back to the browser's default crossfade
      return;
    }
    if (!style) {
      style = document.createElement("style");
      style.id = styleId;
      document.head.appendChild(style);
    }
    style.textContent = css;
  },

  _setupNavigationTransitions() {
    let pendingResolve = null;
    let timeoutId = null;

    // A page declares its entrance transition server-side via `use LiveAnimate`
    // + `@transition "..."`, which pushes this event on mount. It arrives during
    // the DOM patch — before the view transition's animation phase — so applying
    // the style here is in time for the crossing.
    window.addEventListener("phx:lm:page-transition", (e) => {
      this._applyPageTransitionStyle(e.detail && e.detail.transition);
    });

    window.addEventListener("phx:page-loading-start", (info) => {
      const kind = info.detail.kind;

      if (kind === "redirect") {
        // A full navigation is the page's entrance and always transitions. Reset
        // to the default crossfade; the destination's mount re-applies its own
        // transition (and apply_to) if it declares one.
        this._applyPageTransitionStyle(null);
      } else if (kind === "patch") {
        // A same-LiveView `live_patch` only transitions when the current page
        // opted in with `apply_to: :all`. Otherwise it stays a plain DOM patch —
        // we don't start a view transition and don't set `_isNavigating`, so FLIP
        // handles any layout change normally.
        if (this._pageTransitionApplyTo !== "all") return;
      } else {
        return; // "initial" / "error" kinds: nothing to transition
      }

      this._isNavigating = true;
      this._navStartedAt = performance.now();

      // Honor reduced motion: skip the view transition entirely (the navigation
      // still happens, just instantly) unless the app globally opted out with
      // config({ respectMotion: false }). Without this, page transitions would
      // animate for users who asked for no motion, even though every element
      // animation collapses to instant. The `_isNavigating` flag is still set/
      // cleared as usual (self-heals via the same timeout/_checkFlip guards).
      if (_prefersReducedMotion() && this._respectMotion !== false) return;

      if (!document.startViewTransition) return;

      // Create the resolver NOW, synchronously — before startViewTransition's
      // update callback runs. That callback fires on a later rendering tick, but
      // a fast `live_patch` round-trip (milliseconds on localhost) can dispatch
      // page-loading-stop *before* it. So page-loading-stop must be able to
      // resolve the transition whether or not the callback has run yet. Installing
      // the resolver inside the callback races: stop fires with no resolver to
      // call, the callback then awaits a promise nothing settles, and the
      // transition hangs until the safety timeout — a multi-second delay with no
      // visible animation. The DOM is already patched by the time stop fires
      // (LiveView calls `done()` after applying the diff), so resolving on stop
      // lets the transition snapshot the new state and animate immediately.
      if (pendingResolve) pendingResolve(); // settle any superseded transition
      const domUpdated = new Promise((resolve) => { pendingResolve = resolve; });

      if (timeoutId) clearTimeout(timeoutId);
      // Safety: resolve after a timeout if stop never fires (aborted/errored nav),
      // and clear the navigation flag so FLIP isn't disabled for the session.
      timeoutId = setTimeout(() => {
        this._isNavigating = false;
        if (pendingResolve) { pendingResolve(); pendingResolve = null; }
      }, TRANSITION_TIMEOUT);

      document.startViewTransition(() => domUpdated);
    });

    window.addEventListener("phx:page-loading-stop", () => {
      if (pendingResolve) { pendingResolve(); pendingResolve = null; }
      if (timeoutId) {
        clearTimeout(timeoutId);
        timeoutId = null;
      }
      requestAnimationFrame(() => {
        this._isNavigating = false;
        // Sync positions to the new page state
        this._layoutElements.forEach((entry) => {
          if (entry.el.isConnected) entry.pos = this._absPos(entry.el);
        });
      });
    });
  }
};

export { generateSpringEasing };

export const getStylesForPreset = (presetName) => {
  const styles = LiveAnimate._userVariants[presetName] || Presets[presetName] || null;
  if (!styles && typeof console !== "undefined") {
    console.warn(`[LiveAnimate] Unknown preset: "${presetName}"`);
  }
  return styles;
};

export default LiveAnimate;