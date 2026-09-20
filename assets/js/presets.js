// Presets are expressed with the *individual* CSS transform properties
// (`translate`, `scale`, `rotate`) rather than the monolithic `transform`
// shorthand. Each is a separate animatable property, so a hover `scale`, a drag
// `translate`, and a FLIP `translate` compose in the cascade instead of
// clobbering one another. Identity/rest values per property live in
// `IDENTITY_VALUES` in live_animate.js (used to build the "natural" keyframe).
//
// Value syntax reminders:
//   translate: "<x> <y>"   e.g. "0px 30px"  (single value = x, y defaults to 0)
//   scale:     "<x> <y>?"  e.g. "0.8" (uniform) or "1.25 0.75" (x y)
//   rotate:    "<angle>" | "<axis> <angle>" | "<x> <y> <z> <angle>"
//              e.g. "3deg", "x 90deg", "1 1 0 90deg"
export const Presets = {
    // ─── Entrance / Exit ───
    // Each preset describes the "effect" state (hidden/offset).
    // Direction (in vs out) is determined by the component prop.
    "fade": { opacity: 0 },
    "blur": { opacity: 0, filter: "blur(8px)" },
    "slide-up": { opacity: 0, translate: "0px 30px" },
    "slide-down": { opacity: 0, translate: "0px -30px" },
    "slide-left": { opacity: 0, translate: "30px 0px" },
    "slide-right": { opacity: 0, translate: "-30px 0px" },
    "zoom-in": { opacity: 0, scale: "0.8" },
    "zoom-out": { opacity: 0, scale: "1.2" },
    "drop": { opacity: 0, translate: "0px -50px", scale: "0.9" },
    "flip-x": { opacity: 0, rotate: "x 90deg" },
    "flip-y": { opacity: 0, rotate: "y 90deg" },

    // ─── Gesture ───
    // Describes the "active" state applied on hover/tap.
    "scale-up": { scale: "1.05" },
    "scale-down": { scale: "0.95" },
    "press": { scale: "0.92" },
    "lift": { scale: "1.02", filter: "drop-shadow(0 8px 16px rgba(0,0,0,0.15))" },
    "tilt-left": { rotate: "-3deg" },
    "tilt-right": { rotate: "3deg" },

    // ─── Keyframe ───
    "shake": [
        { translate: "0px" },
        { translate: "-5px" },
        { translate: "5px" },
        { translate: "0px" }
    ],
    "bounce": [
        { translate: "0px 0px" },
        { translate: "0px -15px" },
        { translate: "0px 0px" },
        { translate: "0px -7px" },
        { translate: "0px 0px" }
    ],
    "pulse": [
        { scale: "1" },
        { scale: "1.08" },
        { scale: "1" }
    ],
    "wiggle": [
        { rotate: "0deg" },
        { rotate: "-5deg" },
        { rotate: "5deg" },
        { rotate: "-3deg" },
        { rotate: "0deg" }
    ],
    "spin": [
        { rotate: "0deg" },
        { rotate: "360deg" }
    ],
    "ping": [
        { scale: "1", opacity: 1 },
        { scale: "1.5", opacity: 0 }
    ],
    "rubber-band": [
        { scale: "1" },
        { scale: "1.25 0.75" },
        { scale: "0.85 1.15" },
        { scale: "1.1 0.9" },
        { scale: "0.95 1.05" },
        { scale: "1" }
    ],
    // Gentle ambient bob — use with `loop: true` for idle "alive" motion.
    "float": [
        { translate: "0px 0px" },
        { translate: "0px -6px" },
        { translate: "0px 0px" }
    ],
    // Non-displacing attention pulse — a ring + tint that flash and settle,
    // for drawing the eye to a server-updated element (a new/changed stream row,
    // a saved field) without moving it. Themeable: set `--lm-highlight` to an
    // "r, g, b" triplet (default is a blue). Pairs naturally with LiveView
    // pushing updates.
    "highlight": [
        { boxShadow: "0 0 0 0 rgba(var(--lm-highlight, 59, 130, 246), 0)", backgroundColor: "rgba(var(--lm-highlight, 59, 130, 246), 0)" },
        { boxShadow: "0 0 0 4px rgba(var(--lm-highlight, 59, 130, 246), 0.45)", backgroundColor: "rgba(var(--lm-highlight, 59, 130, 246), 0.12)" },
        { boxShadow: "0 0 0 0 rgba(var(--lm-highlight, 59, 130, 246), 0)", backgroundColor: "rgba(var(--lm-highlight, 59, 130, 246), 0)" }
    ]
};
