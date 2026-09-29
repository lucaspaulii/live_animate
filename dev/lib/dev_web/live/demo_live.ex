defmodule DevWeb.AppWeb.DemoLive do
  use DevWeb.AppWeb, :live_view

  @initial_items [
    %{id: 1, text: "Build the interception spike"},
    %{id: 2, text: "Wrap LiveView patches in View Transitions"},
    %{id: 3, text: "Delay element removal with exit animations"},
    %{id: 4, text: "Implement spring physics easing"},
    %{id: 5, text: "Create the <.motion> component"}
  ]

  @github_url "https://github.com/lucaspaulii/live_animate"
  @maintainer "Lucas Pauli"
  @maintainer_url "https://github.com/lucaspaulii"

  # One curated palette, one visual rule: every coloured surface in the demo is a
  # soft `/15` hue fill behind an opacity-matched `/30` hue border. Nothing is a
  # saturated solid — that keeps the whole page in a single calm tile language and
  # lets the *motion* be the only vivid thing. Tiles cycle these in order, so each
  # grid reads as a deliberate spectrum rather than a random rainbow.
  #
  # NB: these MUST be literal class strings — Tailwind only generates what it can
  # find in source, so the hue can never be string-interpolated at runtime.
  @tints [
    "bg-blue-500/15 border-blue-500/30",
    "bg-violet-500/15 border-violet-500/30",
    "bg-emerald-500/15 border-emerald-500/30",
    "bg-amber-500/15 border-amber-500/30",
    "bg-rose-500/15 border-rose-500/30",
    "bg-cyan-500/15 border-cyan-500/30",
    "bg-indigo-500/15 border-indigo-500/30",
    "bg-teal-500/15 border-teal-500/30",
    "bg-fuchsia-500/15 border-fuchsia-500/30",
    "bg-sky-500/15 border-sky-500/30",
    "bg-orange-500/15 border-orange-500/30",
    "bg-lime-500/15 border-lime-500/30"
  ]

  # Just the hue fill + border for surfaces with their own shape (drag handles,
  # grid blocks, swipe cards); pair it with `rounded-2xl border` at the call site.
  defp tint(i), do: Enum.at(@tints, rem(i, length(@tints)))

  # A complete label tile: shared shape + hue + padding.
  defp tile(i, extra \\ "p-4 sm:p-6") do
    # Flex-center the label on BOTH axes — `text-center` alone only centers
    # horizontally, leaving the label top-aligned in the padded box (obvious on
    # the square-ish dense grids like stagger/delay/duration). Padding is smaller
    # on mobile so narrow tiles don't cramp wider labels ("1000ms") onto two lines.
    String.trim(
      "flex items-center justify-center text-center rounded-2xl border shadow-sm #{tint(i)} #{extra}"
    )
  end

  def mount(_params, _session, socket) do
    grid_blocks =
      Enum.map(1..12, fn i ->
        %{id: i, color: tint(i - 1), label: "#{i}"}
      end)

    {:ok,
     socket
     |> assign(
       github_url: @github_url,
       maintainer: @maintainer,
       maintainer_url: @maintainer_url,
       next_id: 6,
       show_flip: true,
       drag_pos: %{x: 0, y: 0},
       slider_x: 0,
       swipe_cards: [
         %{id: 1, text: "Swipe me right to dismiss", color: tint(0)},
         %{id: 2, text: "Swipe me too", color: tint(1)},
         %{id: 3, text: "And me", color: tint(2)}
       ],
       swipe_next_id: 4,
       grid_next_id: 13,
       layout_expanded: false,
       entrance_presets:
         ~w(fade blur slide-up slide-down slide-left slide-right zoom-in zoom-out drop flip-x flip-y),
       gesture_presets: ~w(scale-up scale-down press lift tilt-left tilt-right),
       keyframe_presets: ~w(shake bounce pulse wiggle spin ping rubber-band float highlight)
     )
     |> stream(:items, @initial_items)
     |> stream(:grid_blocks, grid_blocks)}
  end

  def handle_event("add", _params, socket) do
    new_item = %{id: socket.assigns.next_id, text: "New item ##{socket.assigns.next_id}"}

    {:noreply,
     socket
     |> assign(next_id: socket.assigns.next_id + 1)
     |> stream_insert(:items, new_item)}
  end

  def handle_event("remove", %{"id" => id}, socket) do
    id = String.to_integer(id)
    {:noreply, stream_delete_by_dom_id(socket, :items, "items-#{id}")}
  end

  def handle_event("toggle_flip", _params, socket) do
    {:noreply, assign(socket, show_flip: !socket.assigns.show_flip)}
  end

  def handle_event("toggle_layout", _params, socket) do
    {:noreply, assign(socket, layout_expanded: !socket.assigns.layout_expanded)}
  end

  def handle_event("remove_block", %{"id" => id}, socket) do
    id = String.to_integer(id)
    {:noreply, stream_delete_by_dom_id(socket, :grid_blocks, "grid_blocks-#{id}")}
  end

  def handle_event("add_block", _params, socket) do
    id = socket.assigns.grid_next_id
    block = %{id: id, color: tint(id - 1), label: "#{id}"}

    {:noreply,
     socket
     |> assign(grid_next_id: id + 1)
     |> stream_insert(:grid_blocks, block)}
  end

  def handle_event("drag_tracked", %{"x" => x, "y" => y}, socket) do
    {:noreply, assign(socket, drag_pos: %{x: round(x), y: round(y)})}
  end

  def handle_event("slider_moved", %{"x" => x}, socket) do
    {:noreply, assign(socket, slider_x: round(x))}
  end

  def handle_event("swipe_dismiss", %{"x" => x, "id" => id}, socket) do
    if x > 80 do
      card_id = id |> String.replace("swipe-", "") |> String.to_integer()
      cards = Enum.reject(socket.assigns.swipe_cards, &(&1.id == card_id))

      next_id = socket.assigns.swipe_next_id
      new_card = %{id: next_id, text: "Card ##{next_id}", color: tint(next_id - 1)}

      {:noreply,
       assign(socket,
         swipe_cards: cards ++ [new_card],
         swipe_next_id: next_id + 1
       )}
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl space-y-14 px-5 py-16 sm:py-24">
      <%!-- Header — large title, calm supporting copy, quiet pill actions --%>
      <header
        id="demo-header"
        phx-update="ignore"
        class="flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between"
      >
        <div>
          <h1 class="mb-3 text-4xl font-semibold tracking-tight sm:text-5xl">LiveAnimate Demo</h1>
          <p class="max-w-xl text-base leading-relaxed text-base-content/60">
            Every animation property in action. Click a preset in the
            <strong class="font-semibold text-base-content/80">page-transition</strong>
            bar below to see <strong class="font-semibold text-base-content/80">View Transitions</strong>.
          </p>
        </div>
        <div class="flex shrink-0 gap-2">
          <.link
            navigate="/playground"
            class="btn btn-sm gap-2 rounded-full border-base-300 bg-base-100 shadow-sm"
          >
            <.icon name="hero-beaker" class="size-4" /> Playground
          </.link>
          <a
            href={@github_url}
            target="_blank"
            rel="noopener"
            class="btn btn-sm gap-2 rounded-full border-base-300 bg-base-100 shadow-sm"
          >
            <.github_icon /> GitHub
          </a>
        </div>
      </header>

      <%!-- Page-transition showcase nav: click a preset to navigate with that transition --%>
      <DevWeb.AppWeb.TransitionDemo.transition_nav />

      <%!-- ─── Entrance / Exit Presets ─── --%>
      <.motion tag="section" layout={true} id="sec-entrance">
        <.section_head title="Entrance / Exit Presets" desc="Scroll away and back to replay." />
        <.group>
          <div class="grid grid-cols-3 gap-3 sm:grid-cols-4">
            <.motion
              :for={{name, i} <- Enum.with_index(@entrance_presets)}
              id={"p-#{name}"}
              in_view={%{action: name, repeat: true, duration: 1500}}
              class={tile(i)}
            >
              <span class="text-sm font-medium">{name}</span>
            </.motion>
          </div>
        </.group>
      </.motion>

      <%!-- ─── Gesture Presets ─── --%>
      <.motion tag="section" layout={true} id="sec-gesture">
        <.section_head title="Gesture Presets" desc="Hover to preview each effect." />
        <.group>
          <div class="grid grid-cols-3 gap-3">
            <.motion
              :for={{name, i} <- Enum.with_index(@gesture_presets)}
              id={"g-#{name}"}
              hover={name}
              class={tile(i, "p-6 text-center cursor-pointer select-none")}
            >
              <span class="text-sm font-medium">{name}</span>
            </.motion>
          </div>
        </.group>
      </.motion>

      <%!-- ─── Keyframe Presets ─── --%>
      <.motion tag="section" layout={true} id="sec-keyframe">
        <.section_head title="Keyframe Presets" desc="Looping continuously." />
        <.group>
          <div class="grid grid-cols-3 gap-3 sm:grid-cols-4">
            <.motion
              :for={{name, i} <- Enum.with_index(@keyframe_presets)}
              id={"k-#{name}"}
              animate={%{action: name, loop: true, duration: 1000, interval: 1000}}
              class={tile(i)}
            >
              <span class="text-sm font-medium">{name}</span>
            </.motion>
          </div>
        </.group>
      </.motion>

      <%!-- ─── Custom Keyframes ─── --%>
      <.motion tag="section" layout={true} id="sec-custom">
        <.section_head title="Custom Keyframes" desc="No presets — raw keyframes passed inline." />
        <.group>
          <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <.motion
              id="custom-disco"
              animate={
                %{
                  keyframes: [
                    %{rotate: "0deg", scale: "1", "background-color": "rgba(244,114,182,0.15)"},
                    %{rotate: "90deg", scale: "1.3", "background-color": "rgba(250,204,21,0.15)"},
                    %{rotate: "180deg", scale: "0.7", "background-color": "rgba(52,211,153,0.15)"},
                    %{rotate: "270deg", scale: "1.2", "background-color": "rgba(96,165,250,0.15)"},
                    %{rotate: "360deg", scale: "1", "background-color": "rgba(244,114,182,0.15)"}
                  ],
                  loop: true,
                  duration: 2000
                }
              }
              class="rounded-2xl border border-pink-500/30 bg-pink-500/15 p-6 text-center shadow-sm"
            >
              <span class="text-sm font-bold text-base-content">Disco</span>
            </.motion>

            <.motion
              id="custom-glitch"
              animate={
                %{
                  keyframes: [
                    %{transform: "translate(0, 0) skewX(0deg)", opacity: 1},
                    %{transform: "translate(-3px, 2px) skewX(5deg)", opacity: 0.8},
                    %{transform: "translate(3px, -1px) skewX(-3deg)", opacity: 1},
                    %{transform: "translate(-2px, 0) skewX(8deg)", opacity: 0.6},
                    %{transform: "translate(0, 0) skewX(0deg)", opacity: 1}
                  ],
                  loop: true,
                  duration: 400,
                  interval: 3000
                }
              }
              class={tile(4)}
            >
              <span class="text-sm font-bold">Glitch</span>
            </.motion>

            <.motion
              id="custom-jelly"
              animate={
                %{
                  keyframes: [
                    %{transform: "scale(1, 1)"},
                    %{transform: "scale(1.25, 0.75)"},
                    %{transform: "scale(0.85, 1.15)"},
                    %{transform: "scale(1.15, 0.85)"},
                    %{transform: "scale(0.95, 1.05)"},
                    %{transform: "scale(1, 1)"}
                  ],
                  loop: true,
                  duration: 800,
                  interval: 1500
                }
              }
              class={tile(2)}
            >
              <span class="text-sm font-bold">Jelly</span>
            </.motion>

            <.motion
              id="custom-orbit"
              animate={
                %{
                  keyframes: [
                    %{transform: "rotate(0deg) translateX(20px) rotate(0deg)"},
                    %{transform: "rotate(360deg) translateX(20px) rotate(-360deg)"}
                  ],
                  loop: true,
                  duration: 3000
                }
              }
              class={tile(5)}
            >
              <span class="text-sm font-bold">Orbit</span>
            </.motion>
          </div>
        </.group>
      </.motion>

      <%!-- ─── Exit Animations ─── --%>
      <.motion tag="section" layout={true} id="sec-exit">
        <.section_head title="Exit Animations" desc="Toggle to see exit animations." />
        <.group>
          <button
            phx-click="toggle_flip"
            class="btn btn-sm mb-4 rounded-full border-base-300 bg-base-100 shadow-sm"
          >
            {if @show_flip, do: "Remove cards", else: "Show cards"}
          </button>
          <div class="grid grid-cols-2 gap-3">
            <%= if @show_flip do %>
              <.motion
                id="flip-x-card"
                animate="flip-x"
                exit={%{action: "flip-x", duration: 500}}
                duration={600}
                class={tile(0)}
              >
                <span class="text-sm font-medium">flip-x</span>
              </.motion>

              <.motion
                id="flip-y-card"
                animate="flip-y"
                exit={%{action: "flip-y", duration: 500}}
                duration={600}
                class={tile(1)}
              >
                <span class="text-sm font-medium">flip-y</span>
              </.motion>
            <% end %>
          </div>
        </.group>
      </.motion>

      <%!-- ─── Layout / FLIP ─── --%>
      <.motion tag="section" layout={true} id="sec-layout">
        <.section_head
          title="Layout Animation (FLIP)"
          desc="Elements smoothly animate to their new positions when the layout changes."
        />
        <.group class="space-y-8">
          <%!-- Non-stream layout toggle --%>
          <div>
            <h3 class="mb-3 text-sm font-semibold text-base-content/70">Toggle Layout</h3>
            <button
              phx-click="toggle_layout"
              class="btn btn-sm mb-4 rounded-full border-base-300 bg-base-100 shadow-sm"
            >
              {if @layout_expanded, do: "Collapse", else: "Expand"}
            </button>
            <div class={[
              "grid gap-3 transition-none",
              if(@layout_expanded, do: "grid-cols-2", else: "grid-cols-4")
            ]}>
              <.motion
                id="layout-a"
                layout={true}
                animate="fade"
                class={tile(0)}
              >
                <span class="font-bold text-base-content">A</span>
              </.motion>
              <.motion
                id="layout-b"
                layout={true}
                animate="fade"
                class={tile(1)}
              >
                <span class="font-bold text-base-content">B</span>
              </.motion>
              <.motion
                id="layout-c"
                layout={true}
                animate="fade"
                class={tile(2)}
              >
                <span class="font-bold text-base-content">C</span>
              </.motion>
              <.motion
                id="layout-d"
                layout={true}
                animate="fade"
                class={tile(3)}
              >
                <span class="font-bold text-base-content">D</span>
              </.motion>
            </div>
          </div>

          <%!-- Stream grid --%>
          <div>
            <h3 class="mb-1 text-sm font-semibold text-base-content/70">Grid Reflow</h3>
            <p class="mb-3 text-sm text-base-content/50">Click a block to remove it.</p>
            <button phx-click="add_block" class="btn btn-sm btn-neutral mb-4 rounded-full">
              Add block
            </button>
            <div id="grid-blocks" phx-update="stream" class="grid grid-cols-4 gap-3">
              <.motion
                :for={{dom_id, block} <- @streams.grid_blocks}
                id={dom_id}
                layout={true}
                animate="zoom-in"
                exit={%{action: "zoom-out", duration: 300}}
                class={"flex aspect-square w-full cursor-pointer items-center justify-center rounded-2xl border shadow-sm #{block.color}"}
                phx-click="remove_block"
                phx-value-id={block.id}
              >
                <span class="text-2xl font-bold text-base-content">{block.label}</span>
              </.motion>
            </div>
          </div>
        </.group>
      </.motion>

      <%!-- ─── Stream List ─── --%>
      <.motion tag="section" layout={true} id="sec-stream">
        <.section_head
          title="Stream List"
          desc="Add/remove items to see layout animations, exit animations, and hover effects."
        />
        <.group>
          <button phx-click="add" class="btn btn-sm btn-neutral mb-4 rounded-full">Add item</button>

          <ul id="items-list" phx-update="stream" class="space-y-2">
            <.motion
              :for={{dom_id, item} <- @streams.items}
              id={dom_id}
              tag="li"
              layout={true}
              animate={%{action: "fade", duration: 300}}
              exit={%{action: "fade", duration: 300}}
              name={"item-#{item.id}"}
              class="flex cursor-pointer items-center justify-between rounded-2xl border border-base-300 bg-base-100 px-4 py-3.5 shadow-sm"
            >
              <span class="font-medium text-base-content">{item.text}</span>
              <button
                phx-click="remove"
                phx-value-id={item.id}
                class="btn btn-circle btn-ghost btn-xs text-base-content/40 hover:bg-error/10 hover:text-error"
              >
                ✕
              </button>
            </.motion>
          </ul>
        </.group>
      </.motion>

      <%!-- ─── Drag ─── --%>
      <.motion tag="section" layout={true} id="sec-drag">
        <.section_head
          title="Drag"
          desc="Free drag, axis lock, constraints, and elastic overscroll."
        />
        <.group class="space-y-8">
          <div class="flex flex-wrap gap-6">
            <div class="text-center">
              <p class="mb-2 text-xs text-base-content/50">Free</p>
              <.motion
                id="drag-free"
                animate="zoom-in"
                drag={true}
                class={"flex h-24 w-24 cursor-grab items-center justify-center rounded-2xl border #{tint(0)} shadow-lg"}
              >
                <span class="text-xs font-bold text-base-content">Free</span>
              </.motion>
            </div>

            <div class="text-center">
              <p class="mb-2 text-xs text-base-content/50">X axis only</p>
              <.motion
                id="drag-x"
                drag={%{axis: "x"}}
                class={"flex h-24 w-24 cursor-grab items-center justify-center rounded-2xl border #{tint(1)} shadow-lg"}
              >
                <span class="text-xs font-bold text-base-content">X only</span>
              </.motion>
            </div>

            <div class="text-center">
              <p class="mb-2 text-xs text-base-content/50">Constrained</p>
              <.motion
                id="drag-bounded"
                drag={%{constraints: %{top: -60, bottom: 60, left: -60, right: 60}}}
                class={"flex h-24 w-24 cursor-grab items-center justify-center rounded-2xl border #{tint(2)} shadow-lg"}
              >
                <span class="text-xs font-bold text-base-content">Bounded</span>
              </.motion>
            </div>

            <div class="text-center">
              <p class="mb-2 text-xs text-base-content/50">Elastic</p>
              <.motion
                id="drag-elastic"
                drag={%{constraints: %{top: -40, bottom: 40, left: -40, right: 40}, elastic: 0.5}}
                class={"flex h-24 w-24 items-center justify-center rounded-2xl border #{tint(3)} shadow-lg"}
              >
                <span class="text-xs font-bold text-base-content">Elastic</span>
              </.motion>
            </div>
          </div>

          <div>
            <p class="mb-3 text-xs text-base-content/50">
              Slider — <code class="text-xs">snap_back: false</code> (stays where you drop it)
            </p>
            <div class="relative h-2 w-64 rounded-full bg-base-300">
              <.motion
                id="drag-slider"
                drag={%{axis: "x", snap_back: false, elastic: 0, constraints: %{left: 0, right: 232}}}
                phx-drag-end="slider_moved"
                class="absolute -top-2 left-0 size-6 cursor-grab rounded-full bg-blue-500 shadow-md"
              >
                <span class="sr-only">Slider handle — drag horizontally</span>
              </.motion>
            </div>
            <p class="mt-3 text-xs text-base-content/60">
              Dropped at <span class="font-mono font-bold text-blue-500">{@slider_x}px</span>
            </p>
          </div>
        </.group>
      </.motion>

      <%!-- ─── Drag Callbacks ─── --%>
      <.motion tag="section" layout={true} id="sec-drag-callbacks">
        <.section_head title="Drag Callbacks">
          <code class="text-xs">phx-drag-end</code> pushes the release position to the server.
        </.section_head>

        <.group>
          <div class="grid grid-cols-1 gap-8 sm:grid-cols-2">
            <%!-- Position tracker --%>
            <div>
              <h3 class="mb-3 text-sm font-semibold text-base-content/70">Position Tracker</h3>
              <div class="flex items-center gap-4">
                <.motion
                  id="drag-tracked"
                  drag={true}
                  phx-drag-end="drag_tracked"
                  class={"flex h-20 w-20 shrink-0 cursor-grab items-center justify-center rounded-2xl border #{tint(6)} shadow-lg"}
                >
                  <span class="text-xs font-bold text-base-content">Drag</span>
                </.motion>
                <div class="font-mono text-sm text-base-content/60">
                  <p>x: <span class="font-bold text-base-content">{@drag_pos.x}px</span></p>
                  <p>y: <span class="font-bold text-base-content">{@drag_pos.y}px</span></p>
                </div>
              </div>
            </div>

            <%!-- Swipe to dismiss --%>
            <div>
              <h3 class="mb-3 text-sm font-semibold text-base-content/70">Swipe to Dismiss</h3>
              <p class="mb-2 text-xs text-base-content/40">Drag right past 80px to remove.</p>
              <div class="space-y-2">
                <.motion
                  :for={card <- @swipe_cards}
                  id={"swipe-#{card.id}"}
                  animate="slide-left"
                  drag={%{axis: "x"}}
                  phx-drag-end="swipe_dismiss"
                  class={"rounded-2xl border #{card.color} px-4 py-3 text-sm font-medium text-base-content shadow-sm"}
                >
                  {card.text}
                </.motion>
                <p :if={@swipe_cards == []} class="text-sm italic text-base-content/40">
                  All dismissed!
                </p>
              </div>
            </div>
          </div>
        </.group>
      </.motion>

      <%!-- ─── Scroll-Linked ─── --%>
      <.motion tag="section" layout={true} id="sec-scroll">
        <.section_head
          title="Scroll-Linked"
          desc={"This element triggers its animation while in the scroll \"sweet spot\"."}
        />
        <.group>
          <.motion
            id="scroll-demo"
            animate="fade"
            scroll="slide-up"
            class={tile(5, "p-8 text-center")}
          >
            <span class="font-medium">Scroll-triggered slide-up</span>
          </.motion>
        </.group>
      </.motion>

      <%!-- ─── Per-Animation Transitions ─── --%>
      <.motion tag="section" layout={true} id="sec-transitions">
        <.section_head
          title="Per-Animation Transitions"
          desc="Each element uses a different transition — spring physics or tween easing. Scroll away and back to replay."
        />
        <.group>
          <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <.motion
              id="tr-bouncy"
              in_view={
                %{
                  action: "slide-up",
                  repeat: true,
                  transition: %{type: "spring", stiffness: 400, damping: 10}
                }
              }
              class={tile(0)}
            >
              <span class="text-sm font-medium">Bouncy</span>
              <span class="block text-xs text-base-content/40">s:400 d:10</span>
            </.motion>

            <.motion
              id="tr-stiff"
              in_view={
                %{
                  action: "slide-up",
                  repeat: true,
                  transition: %{type: "spring", stiffness: 600, damping: 30}
                }
              }
              class={tile(1)}
            >
              <span class="text-sm font-medium">Stiff</span>
              <span class="block text-xs text-base-content/40">s:600 d:30</span>
            </.motion>

            <.motion
              id="tr-gentle"
              in_view={
                %{
                  action: "slide-up",
                  repeat: true,
                  transition: %{type: "spring", stiffness: 50, damping: 8}
                }
              }
              class={tile(2)}
            >
              <span class="text-sm font-medium">Gentle</span>
              <span class="block text-xs text-base-content/40">s:50 d:8</span>
            </.motion>

            <.motion
              id="tr-tween"
              in_view={
                %{
                  action: "slide-up",
                  repeat: true,
                  duration: 600,
                  transition: %{type: "tween", ease: "ease_in_out"}
                }
              }
              class={tile(3)}
            >
              <span class="text-sm font-medium">Tween</span>
              <span class="block text-xs text-base-content/40">ease-in-out</span>
            </.motion>
          </div>
        </.group>
      </.motion>

      <%!-- ─── Stagger ─── --%>
      <.motion tag="section" layout={true} id="sec-stagger">
        <.section_head
          title="Stagger"
          desc="Each child is automatically delayed by its index. Scroll away and back to replay."
        />
        <.group>
          <div class="grid grid-cols-6 gap-3">
            <.motion
              :for={i <- 1..6}
              id={"stagger-#{i}"}
              in_view={%{action: "slide-up", repeat: true}}
              stagger={80.0}
              duration={400}
              class={tile(i)}
            >
              <span class="text-xs font-bold text-base-content/70">{i}</span>
            </.motion>
          </div>
        </.group>
      </.motion>

      <%!-- ─── Delay ─── --%>
      <.motion tag="section" layout={true} id="sec-delay">
        <.section_head
          title="Delay"
          desc="Staggered entrance with increasing delays. Scroll away and back to replay."
        />
        <.group>
          <div class="grid grid-cols-4 gap-3">
            <.motion
              id="delay-0"
              in_view={%{action: "slide-up", repeat: true, duration: 500, delay: 0}}
              class={tile(0)}
            >
              <span class="text-xs font-bold text-base-content/70">0ms</span>
            </.motion>

            <.motion
              id="delay-100"
              in_view={%{action: "slide-up", repeat: true, duration: 500, delay: 100}}
              class={tile(1)}
            >
              <span class="text-xs font-bold text-base-content/70">100ms</span>
            </.motion>

            <.motion
              id="delay-200"
              in_view={%{action: "slide-up", repeat: true, duration: 500, delay: 200}}
              class={tile(2)}
            >
              <span class="text-xs font-bold text-base-content/70">200ms</span>
            </.motion>

            <.motion
              id="delay-300"
              in_view={%{action: "slide-up", repeat: true, duration: 500, delay: 300}}
              class={tile(3)}
            >
              <span class="text-xs font-bold text-base-content/70">300ms</span>
            </.motion>
          </div>
        </.group>
      </.motion>

      <%!-- ─── Duration ─── --%>
      <.motion tag="section" layout={true} id="sec-duration">
        <.section_head
          title="Duration"
          desc="Different durations on every element. Scroll away and back to replay."
        />
        <.group>
          <div class="grid grid-cols-4 gap-3">
            <.motion
              id="dur-100"
              in_view={%{action: "slide-up", repeat: true, duration: 100}}
              class={tile(0)}
            >
              <span class="text-xs font-bold text-base-content/70">100ms</span>
            </.motion>

            <.motion
              id="dur-500"
              in_view={%{action: "slide-up", repeat: true, duration: 500}}
              class={tile(1)}
            >
              <span class="text-xs font-bold text-base-content/70">500ms</span>
            </.motion>

            <.motion
              id="dur-1000"
              in_view={%{action: "slide-up", repeat: true, duration: 1000}}
              class={tile(2)}
            >
              <span class="text-xs font-bold text-base-content/70">1000ms</span>
            </.motion>

            <.motion
              id="dur-3000"
              in_view={%{action: "slide-up", repeat: true, duration: 3000}}
              class={tile(3)}
            >
              <span class="text-xs font-bold text-base-content/70">3000ms</span>
            </.motion>
          </div>
        </.group>
      </.motion>

      <.owner_card
        maintainer={@maintainer}
        maintainer_url={@maintainer_url}
        github_url={@github_url}
      />
    </div>
    """
  end

  # ─── Section header ───
  # Consistent large-title rhythm for every demo section: a tracked-in title with
  # a quiet one-line caption. Pass `desc` for plain text, or an inner block when
  # the caption needs inline markup (e.g. a <code> snippet).
  attr :title, :string, required: true
  attr :desc, :string, default: nil
  slot :inner_block

  defp section_head(assigns) do
    ~H"""
    <div class="mb-5 px-1">
      <h2 class="text-2xl font-semibold tracking-tight">{@title}</h2>
      <p :if={@desc} class="mt-1.5 text-sm leading-relaxed text-base-content/55">{@desc}</p>
      <div
        :if={@inner_block != []}
        class="mt-1.5 text-sm leading-relaxed text-base-content/55"
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ─── Grouped surface ───
  # The iOS "grouped list" container: a soft, rounded panel a step below the tiles
  # it holds, so the tiles read as a set without any hard chrome.
  attr :class, :string, default: nil
  slot :inner_block, required: true

  defp group(assigns) do
    ~H"""
    <div class={["rounded-3xl border border-base-300/70 bg-base-200/50 p-4 sm:p-6", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ─── Owner / maintainer footer ───
  # Small, self-contained section that credits the maintainer and links to the
  # project. Kept as its own component so a donate button can slot into the
  # `actions` area later without disturbing the demo layout.
  attr :maintainer, :string, required: true
  attr :maintainer_url, :string, required: true
  attr :github_url, :string, required: true

  defp owner_card(assigns) do
    ~H"""
    <footer class="mt-8 rounded-3xl border border-base-300/70 bg-base-200/50 p-6">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div class="flex items-center gap-3">
          <div class="flex size-10 items-center justify-center rounded-full bg-base-300 font-semibold text-base-content/70">
            {String.first(@maintainer)}
          </div>
          <div class="leading-tight">
            <p class="text-xs text-base-content/50">Maintained by</p>
            <a
              href={@maintainer_url}
              target="_blank"
              rel="noopener"
              class="font-semibold hover:text-primary"
            >
              {@maintainer}
            </a>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <%!-- Future: donate button slots in here --%>
          <a
            href={@github_url}
            target="_blank"
            rel="noopener"
            class="btn btn-sm gap-2 rounded-full border-base-300 bg-base-100 shadow-sm"
          >
            <.github_icon /> Star on GitHub
          </a>
        </div>
      </div>
    </footer>
    """
  end

  defp github_icon(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" fill="currentColor" class="size-4" aria-hidden="true">
      <path d="M12 .5C5.37.5 0 5.87 0 12.5c0 5.3 3.44 9.8 8.21 11.39.6.11.82-.26.82-.58 0-.29-.01-1.04-.02-2.05-3.34.73-4.04-1.61-4.04-1.61-.55-1.39-1.33-1.76-1.33-1.76-1.09-.75.08-.73.08-.73 1.2.09 1.84 1.24 1.84 1.24 1.07 1.84 2.81 1.31 3.5 1 .11-.78.42-1.31.76-1.61-2.67-.3-5.47-1.34-5.47-5.96 0-1.32.47-2.39 1.24-3.23-.12-.31-.54-1.53.12-3.18 0 0 1.01-.32 3.3 1.23a11.5 11.5 0 0 1 6 0c2.29-1.55 3.3-1.23 3.3-1.23.66 1.65.24 2.87.12 3.18.77.84 1.24 1.91 1.24 3.23 0 4.63-2.8 5.65-5.48 5.95.43.37.81 1.1.81 2.22 0 1.6-.01 2.9-.01 3.29 0 .32.22.7.83.58A12.01 12.01 0 0 0 24 12.5C24 5.87 18.63.5 12 .5Z" />
    </svg>
    """
  end
end
