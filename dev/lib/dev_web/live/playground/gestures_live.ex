defmodule DevWeb.AppWeb.Playground.GesturesLive do
  @moduledoc """
  Gestures lab: hover/tap presets and a drag sandbox (axis lock, constraints,
  elastic overscroll). Because gesture listeners bind once at mount, changing a
  control remounts the element — which also exercises the mount/destroy path.
  """
  use DevWeb.AppWeb, :live_view

  import DevWeb.AppWeb.Playground.Components
  alias DevWeb.AppWeb.Playground.Config

  @gesture_presets Config.presets().gesture

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Gestures",
       gesture_options: [{"none", "none"} | Enum.map(@gesture_presets, &{&1, &1})],
       hover: "lift",
       tap: "press",
       drag_enabled: true,
       drag_axis: "none",
       c_top: -80,
       c_bottom: 80,
       c_left: -150,
       c_right: 150,
       elastic: 0.35,
       replay_key: 0
     )}
  end

  @impl true
  def handle_event("update_controls", params, socket) do
    socket =
      socket
      |> Config.put_str(params, "hover", :hover)
      |> Config.put_str(params, "tap", :tap)
      |> Config.put_str(params, "drag_axis", :drag_axis)
      |> Config.put_int(params, "c_top", :c_top)
      |> Config.put_int(params, "c_bottom", :c_bottom)
      |> Config.put_int(params, "c_left", :c_left)
      |> Config.put_int(params, "c_right", :c_right)
      |> Config.put_float(params, "elastic", :elastic)
      |> bump_replay()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_drag", _params, socket),
    do: {:noreply, socket |> update(:drag_enabled, &(!&1)) |> bump_replay()}

  @impl true
  def handle_event("replay", _params, socket), do: {:noreply, bump_replay(socket)}

  defp bump_replay(socket), do: update(socket, :replay_key, &(&1 + 1))

  defp hover_config("none"), do: nil
  defp hover_config(preset), do: preset

  defp drag_config(%{drag_enabled: false}), do: nil

  defp drag_config(assigns) do
    %{
      constraints: %{
        top: assigns.c_top,
        bottom: assigns.c_bottom,
        left: assigns.c_left,
        right: assigns.c_right
      },
      elastic: assigns.elastic
    }
    |> maybe_put_axis(assigns.drag_axis)
  end

  defp maybe_put_axis(map, "none"), do: map
  defp maybe_put_axis(map, axis), do: Map.put(map, :axis, axis)

  defp generate_code(assigns) do
    lines =
      [
        gesture_line("hover", assigns.hover),
        gesture_line("tap", assigns.tap),
        drag_line(assigns)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    """
    <.motion
      id="interactive"
    #{lines}
      class="rounded-box bg-primary text-primary-content px-8 py-6"
    >
      Interact with me
    </.motion>\
    """
  end

  defp gesture_line(_key, "none"), do: nil
  defp gesture_line(key, preset), do: ~s(  #{key}="#{preset}")

  defp drag_line(%{drag_enabled: false}), do: nil

  defp drag_line(assigns) do
    axis = if assigns.drag_axis != "none", do: ~s(axis: "#{assigns.drag_axis}", ), else: ""

    ~s(  drag={%{#{axis}constraints: %{top: #{assigns.c_top}, bottom: #{assigns.c_bottom}, left: #{assigns.c_left}, right: #{assigns.c_right}}, elastic: #{Config.fmt_float(assigns.elastic)}}})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.playground_layout
      active="/playground/gestures"
      title="Gestures lab"
      subtitle="Hover, tap, and drag with axis locking, constraints, and elastic overscroll."
    >
      <:stage>
        <.stage title="Interact">
          <.motion
            id={"gesture-stage-#{@replay_key}"}
            hover={hover_config(@hover)}
            tap={hover_config(@tap)}
            drag={drag_config(assigns)}
            class="rounded-box bg-primary text-primary-content px-8 py-6 shadow-lg font-medium select-none cursor-grab active:cursor-grabbing"
          >
            {gesture_hint(assigns)}
          </.motion>
        </.stage>

        <.code_panel code={generate_code(assigns)} />
      </:stage>

      <:controls>
        <form phx-change="update_controls" class="space-y-4">
          <div class="rounded-box border border-base-300 p-4 space-y-4">
            <.select_control label="Hover" name="hover" value={@hover} options={@gesture_options} />
            <.select_control label="Tap" name="tap" value={@tap} options={@gesture_options} />
          </div>

          <div class="rounded-box border border-base-300 p-4 space-y-3">
            <label class="flex items-center justify-between cursor-pointer">
              <span class="text-sm font-medium">Drag</span>
              <input type="checkbox" checked={@drag_enabled} phx-click="toggle_drag" class="toggle toggle-primary toggle-sm" />
            </label>

            <div :if={@drag_enabled} class="space-y-3">
              <.segmented
                label="Axis lock"
                name="drag_axis"
                value={@drag_axis}
                options={[{"Free", "none"}, {"X only", "x"}, {"Y only", "y"}]}
              />
              <.slider label="Constraint top" name="c_top" value={@c_top} min={-200} max={0} step={10} />
              <.slider label="Constraint bottom" name="c_bottom" value={@c_bottom} min={0} max={200} step={10} />
              <.slider label="Constraint left" name="c_left" value={@c_left} min={-300} max={0} step={10} />
              <.slider label="Constraint right" name="c_right" value={@c_right} min={0} max={300} step={10} />
              <.slider label="Elastic" name="elastic" value={@elastic} min={0} max={1} step={0.05} />
            </div>
          </div>
        </form>

        <button type="button" phx-click="replay" class="btn btn-ghost btn-block gap-2">
          <.icon name="hero-arrow-path" class="size-4" /> Reset position
        </button>

        <p class="text-xs opacity-50 leading-relaxed">
          Drag releases snap back to the nearest point within the constraint box.
          Elastic 0 = hard clamp, 1 = no resistance.
        </p>
      </:controls>
    </.playground_layout>
    """
  end

  defp gesture_hint(assigns) do
    cond do
      assigns.drag_enabled -> "Drag me"
      assigns.hover != "none" -> "Hover me"
      assigns.tap != "none" -> "Press me"
      true -> "Set a gesture"
    end
  end
end
