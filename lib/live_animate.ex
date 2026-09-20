defmodule LiveAnimate do
  @moduledoc """
  Declarative animations for Phoenix LiveView.

  LiveAnimate adds entrance/exit animations, hover/tap/drag gestures, spring
  physics, scroll and viewport triggers, layout (FLIP) animations, and
  server-driven page transitions through a single `<.motion>` component.
  Animations run on the browser's Web Animations API (WAAPI) for GPU-accelerated
  performance, while the Elixir side stays purely declarative.

  ## Setup

  Add the dependency, wire the JS hook into your LiveSocket, and import the CSS
  (the [README](readme.html) has the step-by-step version):

      # mix.exs
      {:live_animate, "~> 0.1.0"}

  In `assets/js/app.js` — spread the hooks and config into your LiveSocket, then
  call `init()`. Both are required; without the hook, `<.motion>` does nothing:

  ```javascript
  import LiveAnimate from "live_animate"

  const liveSocket = new LiveSocket("/live", Socket, {
    ...LiveAnimate.config(),
    hooks: { ...LiveAnimate.hooks },
    params: { _csrf_token: csrfToken }
  })
  LiveAnimate.init()
  ```

  In `assets/css/app.css`:

  ```css
  @import "../../deps/live_animate/assets/css/live_animate.css";
  ```

  Import the component where you render HEEx (e.g. `html_helpers` in
  `my_app_web.ex`):

      import LiveAnimate

  Now animate anything:

      <.motion id="hero" animate="fade">
        <h1>Hello, world!</h1>
      </.motion>

  ## Animation lifecycle

  Each animation state is a **preset name** (string/atom) or a **map** with
  an `:action` key and optional overrides:

    * `animate` — entrance state played on mount (e.g., `"fade"` animates opacity 0 → 1)
    * `exit` — played before the element is removed from the DOM
    * `hover` — applied while the pointer is over the element
    * `tap` — applied while the element is pressed
    * `drag` — enables drag-and-release with snap-back
    * `in_view` — triggers when the element enters the viewport
    * `scroll` — triggers based on scroll position

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

  ## Transition config

  By default every animation uses a global spring easing curve. You can override
  the easing **per-animation** by adding a `:transition` key to any animation map:

      # Spring with custom physics
      <.motion id="card" animate={%{
        action: "slide-up",
        transition: %{type: "spring", stiffness: 400, damping: 10}
      }} />

      # Tween with CSS easing
      <.motion id="card" animate={%{
        action: "fade",
        transition: %{type: "tween", ease: "ease_in_out", duration: 600}
      }} />

  ### Spring parameters

  | Param | Default | Description |
  |---|---|---|
  | `stiffness` | 100 | Higher = faster, snappier |
  | `damping` | 10 | Higher = less overshoot |
  | `mass` | 1 | Higher = more inertia |

  Spring transitions automatically compute a natural duration from the physics
  params. You can override it with `transition.duration`.

  ### Tween easing values

  Accepts CSS keywords (`"ease_in"`, `"ease_out"`, `"ease_in_out"`, `"linear"`),
  a `cubic-bezier(...)` string, or a 4-element list `[x1, y1, x2, y2]`.

  ## Reduced motion

  Every animation honors the user's `prefers-reduced-motion` setting by default —
  when "Reduce motion" is enabled at the OS level, animations collapse to instant.

  Because that signal is all-or-nothing, you can override it for animations you
  consider decorative or essential (a spinner, a subtle confirmation pulse):

      # This element keeps animating even under reduced motion
      <.motion id="spinner" animate={%{action: "spin", loop: true}} respect_motion={false} />

  Or flip the default globally in `app.js`, still honoring per-element opt-ins:

      LiveAnimate.config({ respectMotion: false })  // ignore the OS setting by default

  With a global `respectMotion: false`, an individual `respect_motion={true}`
  forces that element to honor the preference again. Prefer per-element opt-outs
  over the global switch — a blanket override defeats the accessibility setting.

  ## Global defaults

  Configure a global default spring and/or custom variants in your `app.js`:

      const socketConfig = LiveAnimate.config({
        spring: { stiffness: 200, damping: 20, mass: 1 },
        variants: {
          "card-enter": { opacity: 0, transform: "scale(0.9)" },
          "card-hover": { transform: "scale(1.03)", filter: "brightness(1.1)" }
        },
        // ... other LiveSocket config
      })

  The global spring is used as the default easing for all animations (replacing
  the CSS `--lm-spring` variable). Per-animation `:transition` overrides still
  take priority.

  ## Stagger

  Use the `stagger` attribute to automatically offset each child's animation
  by its sibling index. The value is the delay increment **in milliseconds**
  between each child:

      <div id="list" phx-update="stream">
        <.motion
          :for={{dom_id, item} <- @streams.items}
          id={dom_id}
          animate="slide-left"
          stagger={80.0}
        />
      </div>

  The first child plays immediately, the second after 80ms, the third after
  160ms, and so on. Works with both `animate` and `in_view`.

  ## Drag constraints

  By default `drag={true}` allows free-form dragging with snap-back. Pass a map
  to configure axis locking, bounds, and elastic overscroll:

      # Lock to horizontal axis only
      <.motion id="slider" drag={%{axis: "x"}} />

      # Constrain to a box (pixels from origin)
      <.motion id="bounded" drag={%{
        constraints: %{top: -100, bottom: 100, left: -200, right: 200}
      }} />

      # Elastic overscroll (0 = hard clamp, 1 = no resistance, default 0.35)
      <.motion id="elastic" drag={%{
        constraints: %{top: -50, bottom: 50},
        elastic: 0.5
      }} />

      # Stay where dropped instead of springing back to origin
      <.motion id="slider" drag={%{axis: "x", snap_back: false}} />

  On release the element springs back to its origin by default — a good fit for
  swipe/gesture interactions where the *server* decides the outcome (see the
  drag-end callback below). Pass `snap_back: false` to leave it where you dropped
  it instead, settling within the constraint bounds. The stay-put position is
  held client-side and re-applied after LiveView re-renders, so it survives
  patches. Use `phx-drag-end` when the *server* needs to know where it landed —
  to persist it across a full page reload, or to drive other UI.

  ### Drag-end callback

  Set `phx-drag-end` on the element to receive the release position server-side.
  On each release LiveAnimate pushes that event with the drag offset (pixels from
  the origin) and the element id:

      <.motion id={"card-\#{@card.id}"} drag={true} phx-drag-end="card_dropped">
        <p>{@card.title}</p>
      </.motion>

      # in your LiveView
      def handle_event("card_dropped", %{"x" => x, "y" => y, "id" => id}, socket) do
        # decide what to do with the drop (e.g. dismiss past a threshold, reorder…)
        {:noreply, socket}
      end

  The element still snaps back to its origin visually — this is a notification of
  where it was dropped, not a committed position. Persist it server-side and
  re-render if you want the new position to stick (see the swipe-to-dismiss and
  drag-tracking examples in the demo).

  ## Custom variants

  Variants registered via `LiveAnimate.config({ variants: { ... } })` work
  exactly like built-in presets — reference them by name from Elixir:

      <.motion id="card" animate="card-enter" hover="card-hover" />

  User variants take priority over built-in presets, so you can also override
  defaults (e.g. redefine `"fade"` with a custom opacity value).

  """

  use Phoenix.Component

  @doc """
  Enables server-driven page transitions for a LiveView.

  Add `use LiveAnimate` to a LiveView and declare a `@transition` module
  attribute naming a page-transition preset. When the browser navigates to this
  LiveView (`live_navigate`/`live_redirect`), LiveAnimate drives the
  [View Transitions API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transitions_API)
  with that preset instead of the default crossfade. By default same-LiveView
  `live_patch` updates are **not** transitioned (see "Applying to patches" below).

      defmodule MyAppWeb.HomeLive do
        use MyAppWeb, :live_view
        use LiveAnimate
        @transition "slide-left"
      end

  Available presets: `"fade"`, `"blur"`, `"slide-left"`, `"slide-right"`,
  `"slide-up"`, `"slide-down"`. The transition is defined by the **destination**
  page — it controls how the previous page exits and how this page enters.
  (Page transitions are opacity/translate/filter only: scaling the rasterized
  page snapshot shimmers, so there is no `"zoom"` page preset — use the
  element-level `zoom-in`/`zoom-out` presets for scaling real elements.)

  ## Per-transition timing

  `@transition` accepts either a bare preset string (using the global default
  duration and easing) or a map with `:duration` (ms) and/or `:easing` overrides:

      @transition "slide-left"

      @transition %{preset: "slide-left", duration: 300, easing: "ease-out"}

  `:easing` accepts a CSS keyword (`"ease-out"`, `"ease-in-out"`, `"linear"`),
  a `"cubic-bezier(...)"` string, or a 4-element list `[x1, y1, x2, y2]`. Without
  overrides, transitions inherit the global `--lm-duration-default` /
  `--lm-spring` CSS variables (shared by all View Transitions).

  ## Applying to patches

  By default a transition runs only on **navigation** (`live_navigate` /
  `live_redirect`) — the page's entrance. Same-LiveView `live_patch` updates
  (sorting a table, switching a tab, pagination) stay as plain DOM patches, so
  they update instantly and `layout` (FLIP) animations handle any repositioning.
  Wrapping every patch in a full-page View Transition is usually unwanted and
  fights FLIP, so it's opt-in via `:apply_to`:

      # navigate only (default)
      @transition "slide-left"

      # transition on navigation AND live_patch within this LiveView
      @transition %{preset: "slide-left", apply_to: :all}

      # combine with timing overrides
      @transition %{preset: "slide-left", duration: 300, apply_to: :all}

  `:apply_to` accepts `:navigate` (default) or `:all`. The names mirror LiveView's
  own `<.link navigate={...}>` / `<.link patch={...}>` vocabulary.

  Requires the JS setup from the README (`LiveAnimate.init()` wires the
  navigation hooks). Falls back to the default crossfade in browsers without the
  View Transitions API, and honors `prefers-reduced-motion`.

  This is independent of `import LiveAnimate` — you still import the module to
  use the `<.motion>` component.
  """
  defmacro __using__(_opts) do
    quote do
      # `on_mount/1` is a Phoenix.LiveView macro (imported by `use ..., :live_view`,
      # which must appear before `use LiveAnimate`). It registers
      # `LiveAnimate.on_mount/4` to run on every mount of this LiveView.
      on_mount(LiveAnimate)
      @before_compile LiveAnimate
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    transition = Module.get_attribute(env.module, :transition)

    quote do
      @doc false
      def __lm_transition__, do: unquote(Macro.escape(transition))
    end
  end

  @doc false
  def on_mount(:default, _params, _session, socket) do
    transition =
      if function_exported?(socket.view, :__lm_transition__, 0) do
        socket.view.__lm_transition__()
      end

    socket =
      if transition && Phoenix.LiveView.connected?(socket) do
        Phoenix.LiveView.push_event(socket, "lm:page-transition", %{
          transition: normalize_transition(transition)
        })
      else
        socket
      end

    {:cont, socket}
  end

  @doc false
  # Normalize an author-facing `@transition` value into the JSON-serializable
  # map the JS side consumes: `%{preset, apply_to, duration?, easing?}`. Tuples
  # aren't JSON-encodable, so all shapes collapse to a map here. `apply_to`
  # defaults to "navigate" (transition on navigation only); "all" also transitions
  # same-LiveView `live_patch` updates.
  def normalize_transition(preset) when is_binary(preset) do
    %{preset: preset, apply_to: "navigate"}
  end

  def normalize_transition(%{} = map) do
    # `duration`/`easing` are interpolated verbatim into a `<style>` block on the
    # client (`::view-transition-*(root)` rules). Validate them here so a stray
    # `}`/`;` can never break out of the rule and inject arbitrary CSS — even
    # though `@transition` is a compile-time attribute today, this keeps the
    # config→CSS path safe if a value is ever sourced dynamically. Invalid values
    # are dropped, so the client falls back to the global VT defaults.
    %{preset: Map.get(map, :preset), apply_to: normalize_apply_to(Map.get(map, :apply_to))}
    |> maybe_put(:duration, validate_duration(Map.get(map, :duration)))
    |> maybe_put(:easing, validate_easing(Map.get(map, :easing)))
  end

  def normalize_transition(nil), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp normalize_apply_to(:all), do: "all"
  defp normalize_apply_to("all"), do: "all"
  # Anything else (including :navigate, a typo, or nil) → navigation-only.
  defp normalize_apply_to(_), do: "navigate"

  # A duration is milliseconds — accept only a non-negative number.
  defp validate_duration(n) when is_integer(n) and n >= 0, do: n
  defp validate_duration(n) when is_float(n) and n >= 0, do: n
  defp validate_duration(_), do: nil

  @easing_keywords ~w(linear ease ease-in ease-out ease-in-out ease_in ease_out
                      ease_in_out easeIn easeOut easeInOut)

  # Mirror the client's accepted easing forms: a known keyword, a strict
  # cubic-bezier() with four numeric args, or a 4-element numeric list.
  defp validate_easing(easing) when easing in @easing_keywords, do: easing

  defp validate_easing(easing) when is_binary(easing) do
    if Regex.match?(
         ~r/^cubic-bezier\(\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*\)$/,
         easing
       ),
       do: easing,
       else: nil
  end

  defp validate_easing([_, _, _, _] = list) do
    if Enum.all?(list, &is_number/1), do: list, else: nil
  end

  defp validate_easing(_), do: nil

  @typedoc "A preset name, or a map with `:action` and optional `:duration`, `:delay`, `:transition`, and extra keys."
  @type action :: atom() | String.t() | map()

  @animation_keys [:animate, :exit, :hover, :tap, :drag, :in_view, :scroll]

  attr(:id, :string,
    required: true,
    doc: """
    DOM id, **required and unique across the page** (LiveView itself raises
    "Multiple IDs detected" on duplicates). It is *not* used as the element's
    `view-transition-name` — only elements given an explicit `name` participate
    as their own view-transition group; everything else animates inside the page
    root during navigations. In `:for` comprehensions derive it from the row,
    e.g. `id={"item-\#{item.id}"}` or the stream `dom_id`.
    """
  )

  attr(:tag, :string, default: "div")
  attr(:name, :string, default: nil)

  attr(:animate, :any, default: nil)
  attr(:exit, :any, default: nil)
  attr(:hover, :any, default: nil)
  attr(:tap, :any, default: nil)
  attr(:drag, :any, default: nil)
  attr(:in_view, :any, default: nil)
  attr(:scroll, :any, default: nil)

  attr(:duration, :integer, default: 300)
  attr(:delay, :integer, default: 0)
  attr(:layout, :boolean, default: false)
  attr(:stagger, :float, default: 0.0)

  attr(:respect_motion, :boolean,
    default: nil,
    doc: """
    Per-element `prefers-reduced-motion` policy. Omit (default) to inherit the
    global setting; `false` opts this decorative animation out so it always plays;
    `true` forces it to honor the preference even when the app globally opted out
    via `LiveAnimate.config(%{respectMotion: false})`.
    """
  )

  attr(:rest, :global)
  slot(:inner_block, required: true)

  @doc """
  Renders an animated element.

  Wraps content in a DOM element (default `<div>`) wired to the `LiveAnimate`
  JavaScript hook. All animation configuration is serialized as a JSON
  `data-lm-config` attribute and interpreted client-side.

  ## Examples

  Simple entrance animation:

      <.motion id="card" animate="fade">
        <p>I fade in on mount.</p>
      </.motion>

  Hover and tap interactions:

      <.motion id="btn" animate="fade" hover="scale-up" tap="press">
        <button>Click me</button>
      </.motion>

  Exit animation (plays before LiveView removes the element):

      <.motion id="toast" animate="slide-left" exit={%{action: "fade", duration: 400}}>
        <p>Dismissible toast</p>
      </.motion>

  Scroll-triggered with repeat:

      <.motion id="reveal" in_view={%{action: "slide-up", repeat: true}}>
        <p>I animate every time I enter the viewport.</p>
      </.motion>

  Layout animation (FLIP) for smooth repositioning:

      <.motion id={"item-\#{item.id}"} layout={true} animate="fade">
        <p>{item.text}</p>
      </.motion>

  Custom tag and view transition name:

      <.motion id="nav-item" tag="li" name="nav-active" animate="fade">
        Active
      </.motion>
  """
  @spec motion(map()) :: Phoenix.LiveView.Rendered.t()
  def motion(assigns) do
    config =
      Enum.reduce(@animation_keys, %{}, fn key, acc ->
        case Map.get(assigns, key) do
          nil -> acc
          val -> Map.put(acc, key, normalize_action(val, assigns))
        end
      end)
      |> Map.put(:layout, assigns.layout)
      |> Map.put(:stagger, assigns.stagger)
      |> maybe_put_respect_motion(assigns.respect_motion)

    assigns =
      assign(assigns, :lm_config, config |> Jason.encode!())

    ~H"""
    <.dynamic_tag
      tag_name={@tag}
      id={@id}
      phx-hook="LiveAnimate"
      data-lm-config={@lm_config}
      style={vt_name_style(@name)}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end

  @doc false
  @spec normalize_action(action(), map()) :: map()
  defp normalize_action(true, _assigns), do: %{enabled: true}

  defp normalize_action(action, assigns) when is_atom(action) or is_binary(action) do
    %{action: action, duration: assigns.duration, delay: assigns.delay}
  end

  defp normalize_action(action, assigns) when is_map(action) do
    base = %{
      action: Map.get(action, :action),
      duration: Map.get(action, :duration, assigns.duration),
      delay: Map.get(action, :delay, assigns.delay)
    }

    extra = Map.drop(action, [:action, :duration, :delay])
    Map.merge(base, extra)
  end

  # Only serialize `respect_motion` when the author set it explicitly (true/false),
  # so an omitted attr leaves it out of the config and the JS global default applies.
  defp maybe_put_respect_motion(config, nil), do: config
  defp maybe_put_respect_motion(config, value), do: Map.put(config, :respect_motion, value)

  # Build the inline `view-transition-name` style for an explicit `name`, or nil
  # when no name is given / nothing usable survives sanitizing. Guarding on nil
  # here (rather than emitting `view-transition-name: ;`) means an unusable name
  # leaves the element in the page `(root)` group instead of a broken VT group.
  defp vt_name_style(nil), do: nil

  defp vt_name_style(name) do
    case sanitize_css_ident(name) do
      nil -> nil
      ident -> "view-transition-name: #{ident};"
    end
  end

  # Coerce an author `name` into a valid CSS custom-ident for `view-transition-name`,
  # or nil if nothing usable remains. A custom-ident can't be empty, can't be the
  # keyword `none` (which DISABLES the transition name), and can't start with a
  # digit or a hyphen. Those cases are prefixed with `lm-` so the author's name
  # still yields a usable, distinct group rather than being silently ignored by
  # the browser; already-valid names pass through unchanged so cross-page
  # shared-element matching by `name` still works.
  defp sanitize_css_ident(name) when is_binary(name) do
    cleaned = String.replace(name, ~r/[^a-zA-Z0-9_-]/, "")

    cond do
      cleaned == "" -> nil
      cleaned == "none" -> "lm-none"
      Regex.match?(~r/^[a-zA-Z_]/, cleaned) -> cleaned
      true -> "lm-" <> cleaned
    end
  end

  defp sanitize_css_ident(name) when is_atom(name), do: sanitize_css_ident(Atom.to_string(name))
end
