defmodule DevWeb.AppWeb.Playground.PresetsLive do
  @moduledoc """
  Presets explorer: browse all built-in presets grouped by category, preview the
  selected one on the stage with the current transition, and see the HEEx.

  Doubles as a smoke test that every preset renders and settles cleanly (the
  `commitStyles` release in the hook leaves no stuck transform/opacity).
  """
  use DevWeb.AppWeb, :live_view

  import DevWeb.AppWeb.Playground.Components
  alias DevWeb.AppWeb.Playground.Config

  @category_labels [
    entrance: "Entrance / Exit",
    gesture: "Gesture (hover to preview)",
    keyframe: "Keyframe"
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(Config.default_state())
     |> assign(
       page_title: "Presets",
       ease_options: Config.ease_options(),
       category_labels: @category_labels,
       grouped: Config.presets(),
       preset: "fade",
       stagger: false,
       replay_key: 0
     )}
  end

  @impl true
  def handle_event("select_preset", %{"preset" => preset}, socket) do
    {:noreply, socket |> assign(preset: preset) |> bump_replay()}
  end

  @impl true
  def handle_event("update_controls", params, socket) do
    {:noreply, socket |> Config.put_transition_controls(params) |> bump_replay()}
  end

  @impl true
  def handle_event("toggle_stagger", _params, socket) do
    {:noreply, socket |> update(:stagger, &(!&1)) |> bump_replay()}
  end

  @impl true
  def handle_event("replay", _params, socket), do: {:noreply, bump_replay(socket)}

  defp bump_replay(socket), do: update(socket, :replay_key, &(&1 + 1))

  defp anim_map(assigns), do: %{action: assigns.preset, transition: Config.transition_config(assigns)}

  # The stagger demo only makes sense for on-mount animations, not hover gestures.
  defp stagger_applicable?(preset), do: Config.category_of(preset) != :gesture

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        preview_key: Config.preview_key(assigns.preset),
        stagger_ok: stagger_applicable?(assigns.preset)
      )

    ~H"""
    <.playground_layout
      active="/playground/presets"
      title="Presets"
      subtitle="25 built-in presets. Click one to preview it with the current transition."
    >
      <:stage>
        <.stage title={"Preview — #{@preset}"}>
          <%!-- Gesture presets preview on hover; everything else plays on mount. --%>
          <div :if={@preview_key == :hover} class="flex flex-col items-center gap-3">
            <.motion
              id={"preset-stage-#{@replay_key}"}
              hover={anim_map(assigns)}
              class="rounded-box bg-primary text-primary-content px-8 py-6 shadow-lg font-medium cursor-pointer"
            >
              {@preset}
            </.motion>
            <span class="text-xs opacity-50">Hover the card to play</span>
          </div>

          <div :if={@preview_key == :animate and not @stagger} class="flex items-center justify-center">
            <.motion
              id={"preset-stage-#{@replay_key}"}
              animate={anim_map(assigns)}
              delay={@delay}
              class="rounded-box bg-primary text-primary-content px-8 py-6 shadow-lg font-medium"
            >
              {@preset}
            </.motion>
          </div>

          <div :if={@preview_key == :animate and @stagger} class="flex flex-wrap gap-3 justify-center">
            <.motion
              :for={i <- 1..5}
              id={"preset-stagger-#{i}-#{@replay_key}"}
              animate={anim_map(assigns)}
              stagger={120.0}
              class="rounded-box bg-primary text-primary-content w-14 h-14 flex items-center justify-center shadow font-medium"
            >
              {i}
            </.motion>
          </div>
        </.stage>

        <.code_panel code={
          Config.motion_code(@preset, assigns,
            key: @preview_key,
            delay: @delay,
            content: @preset
          )
        } />
      </:stage>

      <:controls>
        <div class="rounded-box border border-base-300 p-4 space-y-4">
          <form phx-change="update_controls" class="space-y-4">
            <.segmented
              label="Transition"
              name="transition_type"
              value={@transition_type}
              options={[{"Spring", "spring"}, {"Tween", "tween"}]}
            />
            <div :if={@transition_type == "spring"} class="space-y-3">
              <.slider label="Stiffness" name="stiffness" value={@stiffness} min={10} max={1000} step={10} />
              <.slider label="Damping" name="damping" value={@damping} min={1} max={50} step={1} />
              <.slider label="Mass" name="mass" value={@mass} min={0.1} max={5} step={0.1} />
            </div>
            <div :if={@transition_type == "tween"} class="space-y-3">
              <.select_control label="Easing" name="ease" value={@ease} options={@ease_options} />
              <.slider label="Duration" name="duration" value={@duration} min={0} max={2000} step={50} unit="ms" />
            </div>
            <.slider :if={@preview_key == :animate} label="Delay" name="delay" value={@delay} min={0} max={1000} step={50} unit="ms" />
          </form>

          <label :if={@stagger_ok} class="flex items-center justify-between cursor-pointer">
            <span class="text-sm opacity-70">Stagger (5 items)</span>
            <input type="checkbox" checked={@stagger} phx-click="toggle_stagger" class="toggle toggle-primary toggle-sm" />
          </label>
        </div>

        <button type="button" phx-click="replay" class="btn btn-primary btn-block gap-2">
          <.icon name="hero-play" class="size-4" /> Replay
        </button>
      </:controls>

      <div class="space-y-6">
        <section :for={{cat, label} <- @category_labels}>
          <h2 class="text-sm font-semibold uppercase tracking-wide opacity-60 mb-3">{label}</h2>
          <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2">
            <button
              :for={name <- @grouped[cat]}
              type="button"
              phx-click="select_preset"
              phx-value-preset={name}
              class={[
                "rounded-lg border px-3 py-2 text-sm text-left transition-colors",
                if(@preset == name,
                  do: "border-primary bg-primary/10 text-primary font-medium",
                  else: "border-base-300 hover:bg-base-200"
                )
              ]}
            >
              {name}
            </button>
          </div>
        </section>
      </div>
    </.playground_layout>
    """
  end
end
