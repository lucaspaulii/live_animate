defmodule DevWeb.AppWeb.PlaygroundLive do
  @moduledoc """
  Playground hub / overview. A compact quick-start that wires a single preset
  end-to-end (tune -> live preview -> copy-paste HEEx). Fuller exploration lives
  in the dedicated sections (Presets, Transitions, ...).
  """
  use DevWeb.AppWeb, :live_view

  import DevWeb.AppWeb.Playground.Components
  alias DevWeb.AppWeb.Playground.Config

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(Config.default_state())
     |> assign(
       page_title: "Playground",
       presets: Config.presets().entrance,
       ease_options: Config.ease_options(),
       preset: "slide-up",
       replay_key: 0
     )}
  end

  @impl true
  def handle_event("update_controls", params, socket) do
    socket =
      socket
      |> Config.put_str(params, "preset", :preset)
      |> Config.put_transition_controls(params)
      |> bump_replay()

    {:noreply, socket}
  end

  @impl true
  def handle_event("replay", _params, socket), do: {:noreply, bump_replay(socket)}

  # Bumping the key changes the element id, forcing LiveView to remove + re-add
  # the node so the hook's `mounted()` fires and the entrance replays. This also
  # incidentally exercises the mount/destroy path on every tweak.
  defp bump_replay(socket), do: update(socket, :replay_key, &(&1 + 1))

  defp animate_config(assigns) do
    %{action: assigns.preset, transition: Config.transition_config(assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.playground_layout
      active="/playground"
      title="LiveAnimate Playground"
      subtitle="Tune an animation, see it live, copy the HEEx. Explore more in the sections at left."
    >
      <:stage>
        <.stage title="Preview">
          <.motion
            id={"pg-stage-#{@replay_key}"}
            animate={animate_config(assigns)}
            delay={@delay}
            class="rounded-box bg-primary text-primary-content px-8 py-6 shadow-lg font-medium"
          >
            {@preset}
          </.motion>
        </.stage>

        <.code_panel code={Config.motion_code(@preset, assigns, delay: @delay)} />
      </:stage>

      <:controls>
        <form phx-change="update_controls" class="space-y-4">
          <div class="rounded-box border border-base-300 p-4 space-y-4">
            <.select_control label="Preset" name="preset" value={@preset} options={@presets} />
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

            <.slider label="Delay" name="delay" value={@delay} min={0} max={1000} step={50} unit="ms" />
          </div>
        </form>

        <button type="button" phx-click="replay" class="btn btn-primary btn-block gap-2">
          <.icon name="hero-play" class="size-4" /> Replay
        </button>

        <p class="text-xs opacity-50 leading-relaxed">
          Every tweak remounts the element so the entrance replays &mdash; the same path
          production hits on mount.
        </p>
      </:controls>
    </.playground_layout>
    """
  end
end
