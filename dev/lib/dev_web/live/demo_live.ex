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

  @colors ~w(bg-primary bg-secondary bg-accent bg-info bg-success bg-warning bg-error bg-primary bg-secondary bg-accent bg-info bg-success)

  @card_styles [
    "bg-primary/10 border-primary/30",
    "bg-secondary/10 border-secondary/30",
    "bg-accent/10 border-accent/30",
    "bg-info/10 border-info/30",
    "bg-success/10 border-success/30",
    "bg-warning/10 border-warning/30",
    "bg-error/10 border-error/30"
  ]

  defp with_styles(names) do
    Enum.with_index(names, fn name, i ->
      {name, Enum.at(@card_styles, rem(i, length(@card_styles)))}
    end)
  end

  def mount(_params, _session, socket) do
    grid_blocks =
      Enum.map(1..12, fn i ->
        %{id: i, color: Enum.at(@colors, i - 1), label: "#{i}"}
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
         %{id: 1, text: "Swipe me right to dismiss", color: "bg-primary"},
         %{id: 2, text: "Swipe me too", color: "bg-secondary"},
         %{id: 3, text: "And me", color: "bg-accent"}
       ],
       swipe_next_id: 4,
       grid_next_id: 13,
       layout_expanded: false,
       entrance_presets:
         with_styles(
           ~w(fade blur slide-up slide-down slide-left slide-right zoom-in zoom-out drop flip-x flip-y)
         ),
       gesture_presets: with_styles(~w(scale-up scale-down press lift tilt-left tilt-right)),
       keyframe_presets: with_styles(~w(shake bounce pulse wiggle spin ping rubber-band float highlight))
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
    color = Enum.at(@colors, rem(id - 1, length(@colors)))
    block = %{id: id, color: color, label: "#{id}"}

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

  @swipe_colors ~w(bg-primary bg-secondary bg-accent bg-info bg-success bg-warning bg-error)

  def handle_event("swipe_dismiss", %{"x" => x, "id" => id}, socket) do
    if x > 80 do
      card_id = id |> String.replace("swipe-", "") |> String.to_integer()
      cards = Enum.reject(socket.assigns.swipe_cards, &(&1.id == card_id))

      next_id = socket.assigns.swipe_next_id
      color = Enum.at(@swipe_colors, rem(next_id - 1, length(@swipe_colors)))
      new_card = %{id: next_id, text: "Card ##{next_id}", color: color}

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
    <div class="max-w-3xl mx-auto py-12 px-4 space-y-16">
      <%!-- Header --%>
      <header id="demo-header" phx-update="ignore" class="flex items-start justify-between gap-4">
        <div>
          <h1 class="text-3xl font-bold mb-2">LiveAnimate Demo</h1>
          <p class="text-base-content/60">
            Every animation property in action. Click a preset in the
            <strong>page-transition</strong> bar below to see <strong>View Transitions</strong>.
          </p>
        </div>
        <a
          href={@github_url}
          target="_blank"
          rel="noopener"
          class="btn btn-sm btn-outline gap-2 shrink-0"
        >
          <.github_icon /> GitHub
        </a>
      </header>

      <%!-- Page-transition showcase nav: click a preset to navigate with that transition --%>
      <DevWeb.AppWeb.TransitionDemo.transition_nav />

      <%!-- ─── Entrance / Exit Presets ─── --%>
      <.motion tag="section" layout={true} id="sec-entrance">
        <h2 class="text-xl font-semibold mb-1">Entrance / Exit Presets</h2>
        <p class="text-base-content/50 text-sm mb-4">Scroll away and back to replay.</p>
        <div class="grid grid-cols-3 sm:grid-cols-4 gap-4">
          <.motion
            :for={{name, style} <- @entrance_presets}
            id={"p-#{name}"}
            in_view={%{action: name, repeat: true, duration: 1500}}
            class={"rounded-box #{style} p-6 text-center"}
          >
            <span class="text-sm font-medium">{name}</span>
          </.motion>
        </div>
      </.motion>

      <%!-- ─── Gesture Presets ─── --%>
      <.motion tag="section" layout={true} id="sec-gesture">
        <h2 class="text-xl font-semibold mb-1">Gesture Presets</h2>
        <p class="text-base-content/50 text-sm mb-4">Hover to preview each effect.</p>
        <div class="grid grid-cols-3 gap-4">
          <.motion
            :for={{name, style} <- @gesture_presets}
            id={"g-#{name}"}
            hover={name}
            class={"rounded-box #{style} p-6 text-center cursor-pointer select-none"}
          >
            <span class="text-sm font-medium">{name}</span>
          </.motion>
        </div>
      </.motion>

      <%!-- ─── Keyframe Presets ─── --%>
      <.motion tag="section" layout={true} id="sec-keyframe">
        <h2 class="text-xl font-semibold mb-1">Keyframe Presets</h2>
        <p class="text-base-content/50 text-sm mb-4">Looping continuously.</p>
        <div class="grid grid-cols-3 sm:grid-cols-4 gap-4">
          <.motion
            :for={{name, style} <- @keyframe_presets}
            id={"k-#{name}"}
            animate={%{action: name, loop: true, duration: 1000, interval: 1000}}
            class={"rounded-box #{style} p-6 text-center"}
          >
            <span class="text-sm font-medium">{name}</span>
          </.motion>
        </div>
      </.motion>

      <%!-- ─── Custom Keyframes ─── --%>
      <.motion tag="section" layout={true} id="sec-custom">
        <h2 class="text-xl font-semibold mb-1">Custom Keyframes</h2>
        <p class="text-base-content/50 text-sm mb-4">No presets — raw keyframes passed inline.</p>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
          <.motion
            id="custom-disco"
            animate={%{
              keyframes: [
                %{rotate: "0deg", scale: "1", "background-color": "#f472b6"},
                %{rotate: "90deg", scale: "1.3", "background-color": "#facc15"},
                %{rotate: "180deg", scale: "0.7", "background-color": "#34d399"},
                %{rotate: "270deg", scale: "1.2", "background-color": "#60a5fa"},
                %{rotate: "360deg", scale: "1", "background-color": "#f472b6"}
              ],
              loop: true,
              duration: 2000
            }}
            class="rounded-box p-6 text-center bg-pink-400"
          >
            <span class="text-sm font-bold text-white drop-shadow">Disco</span>
          </.motion>

          <.motion
            id="custom-glitch"
            animate={%{
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
            }}
            class="rounded-box bg-error/10 border border-error/30 p-6 text-center"
          >
            <span class="text-sm font-bold">Glitch</span>
          </.motion>

          <.motion
            id="custom-jelly"
            animate={%{
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
            }}
            class="rounded-box bg-warning/10 border border-warning/30 p-6 text-center"
          >
            <span class="text-sm font-bold">Jelly</span>
          </.motion>

          <.motion
            id="custom-orbit"
            animate={%{
              keyframes: [
                %{transform: "rotate(0deg) translateX(20px) rotate(0deg)"},
                %{transform: "rotate(360deg) translateX(20px) rotate(-360deg)"}
              ],
              loop: true,
              duration: 3000
            }}
            class="rounded-box bg-info/10 border border-info/30 p-6 text-center"
          >
            <span class="text-sm font-bold">Orbit</span>
          </.motion>
        </div>
      </.motion>

      <%!-- ─── Exit Animations ─── --%>
      <.motion tag="section" layout={true} id="sec-exit">
        <h2 class="text-xl font-semibold mb-1">Exit Animations</h2>
        <p class="text-base-content/50 text-sm mb-4">Toggle to see exit animations.</p>
        <button phx-click="toggle_flip" class="btn btn-sm btn-outline mb-4">
          {if @show_flip, do: "Remove cards", else: "Show cards"}
        </button>
        <div class="grid grid-cols-2 gap-4">
          <%= if @show_flip do %>
            <.motion
              id="flip-x-card"
              animate="flip-x"
              exit={%{action: "flip-x", duration: 500}}
              duration={600}
              class="rounded-box bg-primary/10 border border-primary/30 p-6 text-center"
            >
              <span class="text-sm font-medium">flip-x</span>
            </.motion>

            <.motion
              id="flip-y-card"
              animate="flip-y"
              exit={%{action: "flip-y", duration: 500}}
              duration={600}
              class="rounded-box bg-secondary/10 border border-secondary/30 p-6 text-center"
            >
              <span class="text-sm font-medium">flip-y</span>
            </.motion>
          <% end %>
        </div>
      </.motion>

      <%!-- ─── Layout / FLIP ─── --%>
      <.motion tag="section" layout={true} id="sec-layout">
        <h2 class="text-xl font-semibold mb-1">Layout Animation (FLIP)</h2>
        <p class="text-base-content/50 text-sm mb-4">
          Elements smoothly animate to their new positions when the layout changes.
        </p>

        <%!-- Non-stream layout toggle --%>
        <div class="mb-8">
          <h3 class="text-sm font-semibold text-base-content/70 mb-3">Toggle Layout</h3>
          <button phx-click="toggle_layout" class="btn btn-sm btn-outline mb-4">
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
              class="rounded-box bg-primary p-6 text-center"
            >
              <span class="text-primary-content font-bold">A</span>
            </.motion>
            <.motion
              id="layout-b"
              layout={true}
              animate="fade"
              class="rounded-box bg-secondary p-6 text-center"
            >
              <span class="text-secondary-content font-bold">B</span>
            </.motion>
            <.motion
              id="layout-c"
              layout={true}
              animate="fade"
              class="rounded-box bg-accent p-6 text-center"
            >
              <span class="text-accent-content font-bold">C</span>
            </.motion>
            <.motion
              id="layout-d"
              layout={true}
              animate="fade"
              class="rounded-box bg-info p-6 text-center"
            >
              <span class="text-info-content font-bold">D</span>
            </.motion>
          </div>
        </div>

        <%!-- Stream grid --%>
        <div>
          <h3 class="text-sm font-semibold text-base-content/70 mb-3">Grid Reflow</h3>
          <p class="text-base-content/50 text-sm mb-4">Click a block to remove it.</p>
          <div class="flex gap-2 mb-4">
            <button phx-click="add_block" class="btn btn-primary btn-sm">Add block</button>
          </div>
        </div>
        <div id="grid-blocks" phx-update="stream" class="grid grid-cols-4 gap-3">
          <.motion
            :for={{dom_id, block} <- @streams.grid_blocks}
            id={dom_id}
            layout={true}
            animate="zoom-in"
            exit={%{action: "zoom-out", duration: 300}}
            class={"w-full aspect-square rounded-box flex items-center justify-center cursor-pointer shadow-md #{block.color}"}
            phx-click="remove_block"
            phx-value-id={block.id}
          >
            <span class="text-2xl font-bold text-white drop-shadow">{block.label}</span>
          </.motion>
        </div>
      </.motion>

      <%!-- ─── Stream List ─── --%>
      <.motion tag="section" layout={true} id="sec-stream">
        <h2 class="text-xl font-semibold mb-1">Stream List</h2>
        <p class="text-base-content/50 text-sm mb-4">
          Add/remove items to see layout animations, exit animations, and hover effects.
        </p>
        <div class="flex gap-2 mb-4">
          <button phx-click="add" class="btn btn-primary btn-sm">Add item</button>
        </div>

        <ul id="items-list" phx-update="stream" class="space-y-2">
          <.motion
            :for={{dom_id, item} <- @streams.items}
            id={dom_id}
            tag="li"
            layout={true}
            animate={%{action: "fade", duration: 300}}
            exit={%{action: "fade", duration: 300}}
            name={"item-#{item.id}"}
            class="flex items-center justify-between rounded-box bg-base-200 px-4 py-3 cursor-pointer shadow-sm border border-base-300"
          >
            <span class="font-medium text-base-content">{item.text}</span>
            <button
              phx-click="remove"
              phx-value-id={item.id}
              class="btn btn-circle btn-ghost btn-xs text-error hover:bg-error/10"
            >
              ✕
            </button>
          </.motion>
        </ul>
      </.motion>

      <%!-- ─── Drag ─── --%>
      <.motion tag="section" layout={true} id="sec-drag">
        <h2 class="text-xl font-semibold mb-1">Drag</h2>
        <p class="text-base-content/50 text-sm mb-4">Free drag, axis lock, constraints, and elastic overscroll.</p>
        <div class="flex flex-wrap gap-6">
          <div class="text-center">
            <p class="text-xs text-base-content/50 mb-2">Free</p>
            <.motion
              id="drag-free"
              animate="zoom-in"
              drag={true}
              class="w-24 h-24 rounded-box bg-gradient-to-br from-primary to-secondary flex items-center justify-center shadow-lg cursor-grab"
            >
              <span class="text-primary-content font-bold text-xs">Free</span>
            </.motion>
          </div>

          <div class="text-center">
            <p class="text-xs text-base-content/50 mb-2">X axis only</p>
            <.motion
              id="drag-x"
              drag={%{axis: "x"}}
              class="w-24 h-24 rounded-box bg-gradient-to-br from-accent to-info flex items-center justify-center shadow-lg cursor-grab"
            >
              <span class="text-white font-bold text-xs">X only</span>
            </.motion>
          </div>

          <div class="text-center">
            <p class="text-xs text-base-content/50 mb-2">Constrained</p>
            <.motion
              id="drag-bounded"
              drag={%{constraints: %{top: -60, bottom: 60, left: -60, right: 60}}}
              class="w-24 h-24 rounded-box bg-gradient-to-br from-success to-warning flex items-center justify-center shadow-lg cursor-grab"
            >
              <span class="text-white font-bold text-xs">Bounded</span>
            </.motion>
          </div>

          <div class="text-center">
            <p class="text-xs text-base-content/50 mb-2">Elastic</p>
            <.motion
              id="drag-elastic"
              drag={%{constraints: %{top: -40, bottom: 40, left: -40, right: 40}, elastic: 0.5}}
              class="w-24 h-24 rounded-box bg-gradient-to-br from-error to-warning flex items-center justify-center shadow-lg"
            >
              <span class="text-white font-bold text-xs">Elastic</span>
            </.motion>
          </div>
        </div>

        <div class="mt-8">
          <p class="text-xs text-base-content/50 mb-3">
            Slider — <code class="text-xs">snap_back: false</code> (stays where you drop it)
          </p>
          <div class="relative h-2 w-64 rounded-full bg-base-300">
            <.motion
              id="drag-slider"
              drag={%{axis: "x", snap_back: false, elastic: 0, constraints: %{left: 0, right: 232}}}
              phx-drag-end="slider_moved"
              class="absolute -top-2 left-0 size-6 rounded-full bg-primary shadow-md cursor-grab"
            >
              <span class="sr-only">Slider handle — drag horizontally</span>
            </.motion>
          </div>
          <p class="mt-3 text-xs text-base-content/60">
            Dropped at <span class="font-mono font-bold text-primary">{@slider_x}px</span>
          </p>
        </div>
      </.motion>

      <%!-- ─── Drag Callbacks ─── --%>
      <.motion tag="section" layout={true} id="sec-drag-callbacks">
        <h2 class="text-xl font-semibold mb-1">Drag Callbacks</h2>
        <p class="text-base-content/50 text-sm mb-4">
          <code class="text-xs">phx-drag-end</code> pushes the release position to the server.
        </p>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-8">
          <%!-- Position tracker --%>
          <div>
            <h3 class="text-sm font-semibold text-base-content/70 mb-3">Position Tracker</h3>
            <div class="flex items-center gap-4">
              <.motion
                id="drag-tracked"
                drag={true}
                phx-drag-end="drag_tracked"
                class="w-20 h-20 rounded-box bg-gradient-to-br from-info to-primary flex items-center justify-center shadow-lg shrink-0"
              >
                <span class="text-white font-bold text-xs">Drag</span>
              </.motion>
              <div class="font-mono text-sm text-base-content/60">
                <p>x: <span class="text-base-content font-bold">{@drag_pos.x}px</span></p>
                <p>y: <span class="text-base-content font-bold">{@drag_pos.y}px</span></p>
              </div>
            </div>
          </div>

          <%!-- Swipe to dismiss --%>
          <div>
            <h3 class="text-sm font-semibold text-base-content/70 mb-3">Swipe to Dismiss</h3>
            <p class="text-xs text-base-content/40 mb-2">Drag right past 80px to remove.</p>
            <div class="space-y-2">
              <.motion
                :for={card <- @swipe_cards}
                id={"swipe-#{card.id}"}
                animate="slide-left"
                drag={%{axis: "x"}}
                phx-drag-end="swipe_dismiss"
                class={"rounded-box #{card.color} px-4 py-3 text-white font-medium text-sm shadow"}
              >
                {card.text}
              </.motion>
              <p :if={@swipe_cards == []} class="text-sm text-base-content/40 italic">All dismissed!</p>
            </div>
          </div>
        </div>
      </.motion>

      <%!-- ─── Scroll-Linked ─── --%>
      <.motion tag="section" layout={true} id="sec-scroll">
        <h2 class="text-xl font-semibold mb-1">Scroll-Linked</h2>
        <p class="text-base-content/50 text-sm mb-4">This element triggers its animation while in the scroll "sweet spot".</p>
        <.motion
          id="scroll-demo"
          animate="fade"
          scroll="slide-up"
          class="rounded-box bg-gradient-to-r from-accent/20 to-primary/20 border border-accent/30 p-8 text-center"
        >
          <span class="font-medium">Scroll-triggered slide-up</span>
        </.motion>
      </.motion>

      <%!-- ─── Per-Animation Transitions ─── --%>
      <.motion tag="section" layout={true} id="sec-transitions">
        <h2 class="text-xl font-semibold mb-1">Per-Animation Transitions</h2>
        <p class="text-base-content/50 text-sm mb-4">
          Each element uses a different transition — spring physics or tween easing.
          Scroll away and back to replay.
        </p>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
          <.motion
            id="tr-bouncy"
            in_view={%{
              action: "slide-up",
              repeat: true,
              transition: %{type: "spring", stiffness: 400, damping: 10}
            }}
            class="rounded-box bg-primary/10 border border-primary/30 p-6 text-center"
          >
            <span class="text-sm font-medium">Bouncy</span>
            <span class="text-xs text-base-content/40 block">s:400 d:10</span>
          </.motion>

          <.motion
            id="tr-stiff"
            in_view={%{
              action: "slide-up",
              repeat: true,
              transition: %{type: "spring", stiffness: 600, damping: 30}
            }}
            class="rounded-box bg-secondary/10 border border-secondary/30 p-6 text-center"
          >
            <span class="text-sm font-medium">Stiff</span>
            <span class="text-xs text-base-content/40 block">s:600 d:30</span>
          </.motion>

          <.motion
            id="tr-gentle"
            in_view={%{
              action: "slide-up",
              repeat: true,
              transition: %{type: "spring", stiffness: 50, damping: 8}
            }}
            class="rounded-box bg-accent/10 border border-accent/30 p-6 text-center"
          >
            <span class="text-sm font-medium">Gentle</span>
            <span class="text-xs text-base-content/40 block">s:50 d:8</span>
          </.motion>

          <.motion
            id="tr-tween"
            in_view={%{
              action: "slide-up",
              repeat: true,
              duration: 600,
              transition: %{type: "tween", ease: "ease_in_out"}
            }}
            class="rounded-box bg-info/10 border border-info/30 p-6 text-center"
          >
            <span class="text-sm font-medium">Tween</span>
            <span class="text-xs text-base-content/40 block">ease-in-out</span>
          </.motion>
        </div>
      </.motion>

      <%!-- ─── Stagger ─── --%>
      <.motion tag="section" layout={true} id="sec-stagger">
        <h2 class="text-xl font-semibold mb-1">Stagger</h2>
        <p class="text-base-content/50 text-sm mb-4">
          Each child is automatically delayed by its index. Scroll away and back to replay.
        </p>
        <div class="grid grid-cols-6 gap-3">
          <.motion
            :for={i <- 1..6}
            id={"stagger-#{i}"}
            in_view={%{action: "slide-up", repeat: true}}
            stagger={80.0}
            duration={400}
            class="rounded-box bg-secondary p-6 text-center"
          >
            <span class="text-secondary-content text-xs font-bold">{i}</span>
          </.motion>
        </div>
      </.motion>

      <%!-- ─── Delay ─── --%>
      <.motion tag="section" layout={true} id="sec-delay">
        <h2 class="text-xl font-semibold mb-1">Delay</h2>
        <p class="text-base-content/50 text-sm mb-4">Staggered entrance with increasing delays. Scroll away and back to replay.</p>
        <div class="grid grid-cols-4 gap-4">
          <.motion
            id="delay-0"
            in_view={%{action: "slide-up", repeat: true, duration: 500, delay: 0}}
            class="rounded-box bg-primary p-6 text-center"
          >
            <span class="text-primary-content text-xs font-bold">0ms</span>
          </.motion>

          <.motion
            id="delay-100"
            in_view={%{action: "slide-up", repeat: true, duration: 500, delay: 100}}
            class="rounded-box bg-primary p-6 text-center"
          >
            <span class="text-primary-content text-xs font-bold">100ms</span>
          </.motion>

          <.motion
            id="delay-200"
            in_view={%{action: "slide-up", repeat: true, duration: 500, delay: 200}}
            class="rounded-box bg-primary p-6 text-center"
          >
            <span class="text-primary-content text-xs font-bold">200ms</span>
          </.motion>

          <.motion
            id="delay-300"
            in_view={%{action: "slide-up", repeat: true, duration: 500, delay: 300}}
            class="rounded-box bg-primary p-6 text-center"
          >
            <span class="text-primary-content text-xs font-bold">300ms</span>
          </.motion>
        </div>
      </.motion>

      <%!-- ─── Duration ─── --%>
      <.motion tag="section" layout={true} id="sec-duration">
        <h2 class="text-xl font-semibold mb-1">Duration</h2>
        <p class="text-base-content/50 text-sm mb-4">Different durations on every element. Scroll away and back to replay.</p>
        <div class="grid grid-cols-4 gap-4">
          <.motion
            id="dur-100"
            in_view={%{action: "slide-up", repeat: true, duration: 100}}
            class="rounded-box bg-primary p-6 text-center"
          >
            <span class="text-primary-content text-xs font-bold">100ms</span>
          </.motion>

          <.motion
            id="dur-500"
            in_view={%{action: "slide-up", repeat: true, duration: 500}}
            class="rounded-box bg-primary p-6 text-center"
          >
            <span class="text-primary-content text-xs font-bold">500ms</span>
          </.motion>

          <.motion
            id="dur-1000"
            in_view={%{action: "slide-up", repeat: true, duration: 1000}}
            class="rounded-box bg-primary p-6 text-center"
          >
            <span class="text-primary-content text-xs font-bold">1000ms</span>
          </.motion>

          <.motion
            id="dur-3000"
            in_view={%{action: "slide-up", repeat: true, duration: 3000}}
            class="rounded-box bg-primary p-6 text-center"
          >
            <span class="text-primary-content text-xs font-bold">3000ms</span>
          </.motion>
        </div>
      </.motion>

      <.owner_card
        maintainer={@maintainer}
        maintainer_url={@maintainer_url}
        github_url={@github_url}
      />
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
    <footer class="border-t border-base-300 pt-8 mt-8">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div class="flex items-center gap-3">
          <div class="flex size-10 items-center justify-center rounded-full bg-primary/10 text-primary font-bold">
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
            class="btn btn-sm btn-outline gap-2"
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
