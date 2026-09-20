defmodule DevWeb.AppWeb.Playground.LayoutLive do
  @moduledoc """
  Layout / FLIP lab: reorder a list and expand/collapse a panel with
  `layout={true}` to see smooth FLIP repositioning, then toggle layout off to
  contrast with a hard cut. Exercises the translate-only FLIP from v0.1.
  """
  use DevWeb.AppWeb, :live_view

  import DevWeb.AppWeb.Playground.Components

  @colors ~w(bg-primary bg-secondary bg-accent bg-info bg-success bg-warning)

  @impl true
  def mount(_params, _session, socket) do
    items =
      Enum.map(1..6, fn i ->
        %{id: i, label: "#{i}", color: Enum.at(@colors, i - 1)}
      end)

    {:ok,
     socket
     |> assign(
       page_title: "Layout / FLIP",
       items: items,
       layout_on: true,
       # Bumped on toggle so elements remount with the new layout mode — the hook
       # registers FLIP tracking at mount, so a runtime config change alone won't
       # turn it off. Shuffle keeps ids stable, so reordering still FLIPs.
       layout_key: 0,
       expanded: false
     )}
  end

  @impl true
  def handle_event("shuffle", _params, socket),
    do: {:noreply, update(socket, :items, &Enum.shuffle/1)}

  @impl true
  def handle_event("toggle_layout", _params, socket),
    do: {:noreply, socket |> update(:layout_on, &(!&1)) |> update(:layout_key, &(&1 + 1))}

  @impl true
  def handle_event("toggle_expand", _params, socket),
    do: {:noreply, update(socket, :expanded, &(!&1))}

  defp code(assigns) do
    """
    <.motion
      :for={item <- @items}
      id={"item-\#{item.id}"}
      layout={#{assigns.layout_on}}
      class="rounded-box ..."
    >
      {item.label}
    </.motion>\
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.playground_layout
      active="/playground/layout"
      title="Layout / FLIP"
      subtitle="Reorder or resize with layout={true} and watch elements FLIP into place."
    >
      <:stage>
        <.stage title="Reorder">
          <div class="flex flex-wrap gap-3 justify-center">
            <.motion
              :for={item <- @items}
              id={"layout-item-#{item.id}-#{@layout_key}"}
              layout={@layout_on}
              class={"#{item.color} text-primary-content w-16 h-16 rounded-box flex items-center justify-center text-xl font-bold shadow"}
            >
              {item.label}
            </.motion>
          </div>
        </.stage>
        <button type="button" phx-click="shuffle" class="btn btn-primary btn-sm gap-2">
          <.icon name="hero-arrows-up-down" class="size-4" /> Shuffle order
        </button>

        <.stage title="Expand / collapse (siblings reflow)">
          <div class="flex gap-3 items-start">
            <%!-- Widening the panel pushes the siblings right; with layout on,
                  they FLIP to their new positions instead of jumping. --%>
            <.motion
              id={"layout-panel-#{@layout_key}"}
              layout={@layout_on}
              class={[
                "bg-primary text-primary-content rounded-box p-4 shadow flex items-center justify-center h-20",
                (@expanded && "w-64") || "w-28"
              ]}
            >
              {if @expanded, do: "Expanded", else: "Panel"}
            </.motion>
            <.motion
              id={"layout-sibling-1-#{@layout_key}"}
              layout={@layout_on}
              class="bg-secondary text-secondary-content rounded-box p-4 shadow w-28 h-20 flex items-center justify-center"
            >
              Sibling
            </.motion>
            <.motion
              id={"layout-sibling-2-#{@layout_key}"}
              layout={@layout_on}
              class="bg-accent text-accent-content rounded-box p-4 shadow w-28 h-20 flex items-center justify-center"
            >
              Sibling
            </.motion>
          </div>
        </.stage>
        <button type="button" phx-click="toggle_expand" class="btn btn-primary btn-sm gap-2">
          <.icon name="hero-arrows-pointing-out" class="size-4" />
          {if @expanded, do: "Collapse panel", else: "Expand panel"}
        </button>

        <.code_panel code={code(assigns)} />
      </:stage>

      <:controls>
        <div class="rounded-box border border-base-300 p-4 space-y-4">
          <label class="flex items-center justify-between cursor-pointer">
            <span class="text-sm font-medium">Layout (FLIP)</span>
            <input type="checkbox" checked={@layout_on} phx-click="toggle_layout" class="toggle toggle-primary toggle-sm" />
          </label>
          <p class="text-xs opacity-50">
            Off = hard cut on reorder/resize. On = smooth FLIP. Each control below
            its stage acts on that stage.
          </p>
        </div>

        <p class="text-xs opacity-50 leading-relaxed">
          FLIP is translate-only in v0.1 (see roadmap): position animates, size
          snaps. Full layout projection is on the v2 roadmap.
        </p>
      </:controls>
    </.playground_layout>
    """
  end
end
