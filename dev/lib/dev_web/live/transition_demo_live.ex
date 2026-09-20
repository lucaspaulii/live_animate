defmodule DevWeb.AppWeb.TransitionDemo do
  @moduledoc """
  Page-transition showcase. One thin LiveView per page-transition preset (each
  `use LiveAnimate` + `@transition ...`, which is compile-time), all sharing a
  nav + render. Navigating between them via the top nav triggers the View
  Transition declared by the destination page — so clicking each link *is* the
  demo of that transition.

  Each page also has an `apply_to` toggle and a `live_patch` submenu. Flip the
  toggle, then click a panel: with `:navigate` the patch updates instantly; with
  `:all` the same patch animates with the page's transition. That's the whole
  point of `apply_to`, shown as a live A/B on one page. (The toggle re-pushes the
  transition config the way `@transition` does at compile time — the displayed
  source line updates to match, so it stays an honest picture of the declaration.)
  """
  use DevWeb.AppWeb, :html

  # Preset + optional per-transition timing. `apply_to` is toggled at runtime in
  # the demo (below), so it isn't baked into the spec here. Strings and maps both
  # appear, to show the two accepted `@transition` forms.
  @specs [
    "fade",
    %{preset: "blur", duration: 400},
    %{preset: "slide-left", duration: 300, easing: "ease-out"},
    "slide-right",
    %{preset: "slide-up", duration: 350, easing: "ease-out"},
    "slide-down"
  ]
  def specs, do: @specs

  def preset_of(spec) when is_binary(spec), do: spec
  def preset_of(%{preset: p}), do: p

  def duration_of(spec) when is_binary(spec), do: nil
  def duration_of(%{} = m), do: m[:duration]

  def easing_of(spec) when is_binary(spec), do: nil
  def easing_of(%{} = m), do: m[:easing]

  def presets, do: Enum.map(@specs, &preset_of/1)

  @doc "The `lm:page-transition` payload for a preset at a given scope (what the toggle pushes)."
  def transition_payload(preset, duration, easing, scope) do
    %{preset: preset, apply_to: to_string(scope)}
    |> then(&if(duration, do: Map.put(&1, :duration, duration), else: &1))
    |> then(&if(easing, do: Map.put(&1, :easing, easing), else: &1))
  end

  @doc "The `@transition ...` source line that would produce the current preset/timing/scope."
  def source_for(preset, duration, easing, scope) do
    parts =
      (if duration, do: ["duration: #{duration}"], else: []) ++
        (if easing, do: ["easing: #{inspect(easing)}"], else: []) ++
        (if scope == :all, do: ["apply_to: :all"], else: [])

    if parts == [] do
      ~s|@transition "#{preset}"|
    else
      "@transition %{preset: #{inspect(preset)}, #{Enum.join(parts, ", ")}}"
    end
  end

  attr(:current, :string, default: nil)

  def transition_nav(assigns) do
    assigns = assign(assigns, :presets, presets())

    ~H"""
    <nav class="flex flex-wrap items-center gap-1.5 rounded-box border border-base-300 bg-base-200/50 p-2">
      <span class="px-2 text-xs font-semibold uppercase tracking-wide opacity-60">
        Page transition
      </span>
      <.link
        :for={p <- @presets}
        navigate={"/transitions/#{p}"}
        class={["btn btn-xs", if(p == @current, do: "btn-primary", else: "btn-ghost")]}
      >
        {p}
      </.link>
      <.link :if={@current} navigate="/" class="btn btn-xs btn-ghost ml-auto gap-1">
        <.icon name="hero-arrow-left" class="size-3" /> Back to demo
      </.link>
    </nav>
    """
  end

  @descriptions %{
    "fade" => "A clean crossfade — the safe default.",
    "blur" => "Fade plus a soft blur, for a premium feel.",
    "slide-left" => "Outgoing page slides left, incoming slides in from the right.",
    "slide-right" => "Outgoing page slides right, incoming slides in from the left.",
    "slide-up" => "Outgoing page lifts up, incoming rises from below.",
    "slide-down" => "Outgoing page drops down, incoming descends from above."
  }

  def render_page(assigns) do
    assigns =
      assign(assigns,
        description: Map.get(@descriptions, assigns.current, ""),
        source: source_for(assigns.preset, assigns.duration, assigns.easing, assigns.scope)
      )

    ~H"""
    <div class="space-y-6">
      <.transition_nav current={@current} />

      <div class="rounded-box border border-base-300 bg-base-100 p-10 text-center shadow-sm">
        <div class="text-xs font-semibold uppercase tracking-wide opacity-50">
          You navigated here with
        </div>
        <div class="mt-2 font-mono text-4xl font-bold text-primary">
          {@current}
        </div>
        <p class="mx-auto mt-4 max-w-md text-sm opacity-70">
          {@description}
        </p>

        <div class="mx-auto mt-6 max-w-md">
          <p class="mb-2 text-xs opacity-50">
            Declared on this LiveView as:
          </p>
          <pre class="overflow-x-auto rounded-box bg-base-200 p-3 text-left text-xs"><code>use LiveAnimate
    {@source}</code></pre>
        </div>

        <div class="mx-auto mt-6 max-w-md rounded-box border border-base-300 bg-base-200/40 p-4">
          <p class="mb-1 text-xs font-semibold uppercase tracking-wide opacity-60">
            apply_to
          </p>
          <div class="flex justify-center gap-1.5">
            <button
              type="button"
              phx-click="set_scope"
              phx-value-scope="navigate"
              class={["btn btn-xs", if(@scope == :navigate, do: "btn-primary", else: "btn-ghost")]}
            >
              :navigate
            </button>
            <button
              type="button"
              phx-click="set_scope"
              phx-value-scope="all"
              class={["btn btn-xs", if(@scope == :all, do: "btn-primary", else: "btn-ghost")]}
            >
              :all
            </button>
          </div>

          <p class="mt-4 mb-2 text-xs opacity-60">
            Now click a panel — same LiveView, a <code>live_patch</code> (no navigation):
          </p>
          <div class="flex justify-center gap-1.5">
            <.link
              :for={n <- ["1", "2", "3"]}
              patch={"/transitions/#{@current}?panel=#{n}"}
              class={["btn btn-xs", if(n == @panel, do: "btn-primary", else: "btn-ghost")]}
            >
              Panel {n}
            </.link>
          </div>
          <p class="mt-3 text-xs opacity-70">
            Showing panel <span class="font-mono font-bold text-primary">{@panel}</span> —
            <%= if @scope == :all do %>
              the patch <strong>animates</strong> with this transition
              (<code class="rounded bg-base-300 px-1">apply_to: :all</code>).
            <% else %>
              the patch updates <strong>instantly</strong>
              (<code class="rounded bg-base-300 px-1">apply_to: :navigate</code>, the default) —
              flip the toggle to see it animate.
            <% end %>
          </p>
        </div>

        <p class="mx-auto mt-6 max-w-md text-xs opacity-50">
          Top nav = <code>live_navigate</code> (always transitions). Submenu =
          <code>live_patch</code> (transitions only with <code>apply_to: :all</code>).
        </p>
      </div>
    </div>
    """
  end
end

# Generate one LiveView per spec. Each captures a compile-time `@transition`
# (the navigate-scoped default) and shares the render above. The `apply_to`
# toggle re-pushes `lm:page-transition` at runtime to flip the scope. Values are
# baked into the module body with `unquote(...)` per iteration.
for spec <- DevWeb.AppWeb.TransitionDemo.specs() do
  preset = DevWeb.AppWeb.TransitionDemo.preset_of(spec)
  duration = DevWeb.AppWeb.TransitionDemo.duration_of(spec)
  easing = DevWeb.AppWeb.TransitionDemo.easing_of(spec)
  name = Module.concat(DevWeb.AppWeb.TransitionDemo, Macro.camelize(String.replace(preset, "-", "_")))

  body =
    quote do
      use DevWeb.AppWeb, :live_view
      use LiveAnimate
      @transition unquote(Macro.escape(spec))

      @impl true
      def mount(_params, _session, socket) do
        {:ok,
         assign(socket,
           current: unquote(preset),
           preset: unquote(preset),
           duration: unquote(duration),
           easing: unquote(easing),
           scope: :navigate,
           panel: "1",
           page_title: "Transition: #{unquote(preset)}"
         )}
      end

      # Submenu links are `live_patch`, so param changes land here (mount does not
      # re-run). With `apply_to: :all` the client wraps this patch in the page
      # transition; otherwise it's a plain, instant patch.
      @impl true
      def handle_params(params, _uri, socket) do
        {:noreply, assign(socket, panel: params["panel"] || "1")}
      end

      # Flip apply_to at runtime by re-pushing the transition config with the new
      # scope — the same event `@transition` pushes on mount. Updates the client's
      # patch-transition gate immediately, so the next panel click reflects it.
      @impl true
      def handle_event("set_scope", %{"scope" => scope}, socket) do
        scope = if scope == "all", do: :all, else: :navigate

        payload =
          DevWeb.AppWeb.TransitionDemo.transition_payload(
            socket.assigns.preset,
            socket.assigns.duration,
            socket.assigns.easing,
            scope
          )

        {:noreply,
         socket
         |> assign(scope: scope)
         |> push_event("lm:page-transition", %{transition: payload})}
      end

      @impl true
      def render(assigns), do: DevWeb.AppWeb.TransitionDemo.render_page(assigns)
    end

  Module.create(name, body, Macro.Env.location(__ENV__))
end
