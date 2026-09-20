defmodule DevWeb.AppWeb.Playground.TransitionsLive do
  @moduledoc """
  Transition tuner: the "feel" playground. Tune spring physics or tween easing
  and, in compare mode, run two transitions side by side on the same preset to
  feel the difference — useful for agreeing on a team default spring.

  Also a stress surface for the runtime spring solver: push stiffness/damping to
  extremes and confirm no NaN / crash / stuck element.
  """
  use DevWeb.AppWeb, :live_view

  import DevWeb.AppWeb.Playground.Components
  alias DevWeb.AppWeb.Playground.Config

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Transitions",
       ease_options: Config.ease_options(),
       presets: Config.presets().entrance,
       preset: "slide-up",
       compare: true,
       # Side A: snappy default
       a_transition_type: "spring",
       a_stiffness: 300,
       a_damping: 20,
       a_mass: 1.0,
       a_duration: 300,
       a_ease: "ease_out",
       # Side B: soft / bouncy
       b_transition_type: "spring",
       b_stiffness: 80,
       b_damping: 8,
       b_mass: 1.0,
       b_duration: 600,
       b_ease: "ease_in_out",
       replay_key: 0
     )}
  end

  @impl true
  def handle_event("update_controls", params, socket) do
    {:noreply, socket |> put_all(params) |> bump_replay()}
  end

  @impl true
  def handle_event("toggle_compare", _params, socket) do
    {:noreply, socket |> update(:compare, &(!&1)) |> bump_replay()}
  end

  @impl true
  def handle_event("replay", _params, socket), do: {:noreply, bump_replay(socket)}

  defp put_all(socket, params) do
    socket
    |> Config.put_str(params, "preset", :preset)
    |> Config.put_str(params, "a_transition_type", :a_transition_type)
    |> Config.put_str(params, "a_ease", :a_ease)
    |> Config.put_int(params, "a_stiffness", :a_stiffness)
    |> Config.put_int(params, "a_damping", :a_damping)
    |> Config.put_float(params, "a_mass", :a_mass)
    |> Config.put_int(params, "a_duration", :a_duration)
    |> Config.put_str(params, "b_transition_type", :b_transition_type)
    |> Config.put_str(params, "b_ease", :b_ease)
    |> Config.put_int(params, "b_stiffness", :b_stiffness)
    |> Config.put_int(params, "b_damping", :b_damping)
    |> Config.put_float(params, "b_mass", :b_mass)
    |> Config.put_int(params, "b_duration", :b_duration)
  end

  defp bump_replay(socket), do: update(socket, :replay_key, &(&1 + 1))

  # Extracts one side's controls into the canonical shape Config expects.
  defp side_state(assigns, :a) do
    %{
      transition_type: assigns.a_transition_type,
      stiffness: assigns.a_stiffness,
      damping: assigns.a_damping,
      mass: assigns.a_mass,
      duration: assigns.a_duration,
      ease: assigns.a_ease
    }
  end

  defp side_state(assigns, :b) do
    %{
      transition_type: assigns.b_transition_type,
      stiffness: assigns.b_stiffness,
      damping: assigns.b_damping,
      mass: assigns.b_mass,
      duration: assigns.b_duration,
      ease: assigns.b_ease
    }
  end

  defp anim_map(assigns, side) do
    %{action: assigns.preset, transition: Config.transition_config(side_state(assigns, side))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.playground_layout
      active="/playground/transitions"
      title="Transition tuner"
      subtitle="Dial in spring physics or tween easing. Compare two side by side to pick a default."
    >
      <:stage>
        <.stage title="Preview">
          <div class={["grid gap-6 w-full", @compare && "sm:grid-cols-2"]}>
            <div class="flex flex-col items-center gap-2">
              <.motion
                id={"tr-a-#{@replay_key}"}
                animate={anim_map(assigns, :a)}
                class="rounded-box bg-primary text-primary-content px-8 py-6 shadow-lg font-medium w-full text-center"
              >
                A
              </.motion>
              <span class="text-xs opacity-50 font-mono">{describe(side_state(assigns, :a))}</span>
            </div>

            <div :if={@compare} class="flex flex-col items-center gap-2">
              <.motion
                id={"tr-b-#{@replay_key}"}
                animate={anim_map(assigns, :b)}
                class="rounded-box bg-secondary text-secondary-content px-8 py-6 shadow-lg font-medium w-full text-center"
              >
                B
              </.motion>
              <span class="text-xs opacity-50 font-mono">{describe(side_state(assigns, :b))}</span>
            </div>
          </div>
        </.stage>

        <.code_panel code={Config.motion_code(@preset, side_state(assigns, :a), content: "A")} />
      </:stage>

      <:controls>
        <form phx-change="update_controls" class="space-y-4">
          <div class="rounded-box border border-base-300 p-4 space-y-3">
            <.select_control label="Preset" name="preset" value={@preset} options={@presets} />
          </div>

          <.side_controls
            side="a"
            title="A"
            accent="text-primary"
            transition_type={@a_transition_type}
            stiffness={@a_stiffness}
            damping={@a_damping}
            mass={@a_mass}
            duration={@a_duration}
            ease={@a_ease}
            ease_options={@ease_options}
          />

          <.side_controls
            :if={@compare}
            side="b"
            title="B"
            accent="text-secondary"
            transition_type={@b_transition_type}
            stiffness={@b_stiffness}
            damping={@b_damping}
            mass={@b_mass}
            duration={@b_duration}
            ease={@b_ease}
            ease_options={@ease_options}
          />
        </form>

        <label class="flex items-center justify-between cursor-pointer px-1">
          <span class="text-sm opacity-70">Compare (A vs B)</span>
          <input type="checkbox" checked={@compare} phx-click="toggle_compare" class="toggle toggle-primary toggle-sm" />
        </label>

        <button type="button" phx-click="replay" class="btn btn-primary btn-block gap-2">
          <.icon name="hero-play" class="size-4" /> Replay
        </button>

        <p class="text-xs opacity-50 leading-relaxed">
          Push stiffness/damping to the extremes: the runtime spring solver should
          stay stable (no NaN, no stuck element) at every setting.
        </p>
      </:controls>
    </.playground_layout>
    """
  end

  # A compact one-line description of a side's transition, shown under its card.
  defp describe(%{transition_type: "spring"} = s),
    do: "spring · k=#{s.stiffness} d=#{s.damping} m=#{Config.fmt_float(s.mass)}"

  defp describe(%{transition_type: "tween"} = s),
    do: "tween · #{s.ease} · #{s.duration}ms"

  attr :side, :string, required: true
  attr :title, :string, required: true
  attr :accent, :string, required: true
  attr :transition_type, :string, required: true
  attr :stiffness, :integer, required: true
  attr :damping, :integer, required: true
  attr :mass, :float, required: true
  attr :duration, :integer, required: true
  attr :ease, :string, required: true
  attr :ease_options, :list, required: true

  defp side_controls(assigns) do
    ~H"""
    <div class="rounded-box border border-base-300 p-4 space-y-3">
      <div class={["text-sm font-semibold", @accent]}>Side {@title}</div>
      <.segmented
        label="Transition"
        name={"#{@side}_transition_type"}
        value={@transition_type}
        options={[{"Spring", "spring"}, {"Tween", "tween"}]}
      />
      <div :if={@transition_type == "spring"} class="space-y-3">
        <.slider label="Stiffness" name={"#{@side}_stiffness"} value={@stiffness} min={10} max={1000} step={10} />
        <.slider label="Damping" name={"#{@side}_damping"} value={@damping} min={1} max={50} step={1} />
        <.slider label="Mass" name={"#{@side}_mass"} value={@mass} min={0.1} max={5} step={0.1} />
      </div>
      <div :if={@transition_type == "tween"} class="space-y-3">
        <.select_control label="Easing" name={"#{@side}_ease"} value={@ease} options={@ease_options} />
        <.slider label="Duration" name={"#{@side}_duration"} value={@duration} min={0} max={2000} step={50} unit="ms" />
      </div>
    </div>
    """
  end
end
