defmodule DevWeb.AppWeb.Playground.StreamsLive do
  @moduledoc """
  Streams harness: exercise `<.motion>` inside `phx-update="stream"` — the most
  common real-world integration surface. Covers insert (prepend/append), delete
  (exit), reset, reorder (FLIP), and a limited stream that drops overflow.

  See `demo-playground-plan.md` §4.4.
  """
  use DevWeb.AppWeb, :live_view

  import DevWeb.AppWeb.Playground.Components
  alias DevWeb.AppWeb.Playground.Studies

  @colors ~w(bg-primary bg-secondary bg-accent bg-info bg-success bg-warning bg-error)

  @impl true
  def mount(_params, _session, socket) do
    items = for i <- 1..5, do: item(i)

    {:ok,
     socket
     |> assign(
       page_title: "Streams",
       study: Studies.get(:stream_lifecycle),
       next_id: 6,
       # Streams don't retain a server-side list; we track live ids so we can
       # pick a random one to delete and count what's on screen.
       item_ids: Enum.map(items, & &1.id),
       capped_next: 1
     )
     |> stream(:items, items)
     |> stream(:capped, [])}
  end

  defp item(id), do: %{id: id, label: to_string(id), color: Enum.at(@colors, rem(id - 1, 7))}

  @impl true
  def handle_event("prepend", _p, socket), do: {:noreply, insert(socket, at: 0)}

  @impl true
  def handle_event("append", _p, socket), do: {:noreply, insert(socket, at: -1)}

  @impl true
  def handle_event("delete_random", _p, socket) do
    case socket.assigns.item_ids do
      [] ->
        {:noreply, socket}

      ids ->
        id = Enum.random(ids)

        {:noreply,
         socket
         |> stream_delete(:items, %{id: id})
         |> update(:item_ids, &List.delete(&1, id))}
    end
  end

  @impl true
  def handle_event("reset", _p, socket) do
    items = for i <- 1..5, do: item(i)

    {:noreply,
     socket
     |> stream(:items, items, reset: true)
     |> assign(item_ids: Enum.map(items, & &1.id), next_id: 6)}
  end

  @impl true
  def handle_event("capped_add", _p, socket) do
    id = socket.assigns.capped_next

    {:noreply,
     socket
     # Negative limit keeps the last 8; older items fall off the front.
     |> stream_insert(:capped, item(id), at: -1, limit: -8)
     |> assign(capped_next: id + 1)}
  end

  defp insert(socket, at: at) do
    id = socket.assigns.next_id
    new = item(id)

    socket
    |> stream_insert(:items, new, at: at)
    |> update(:item_ids, fn ids -> if at == 0, do: [id | ids], else: ids ++ [id] end)
    |> assign(next_id: id + 1)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.playground_layout
      active="/playground/streams"
      title="Streams harness"
      subtitle="Animate elements inside a phx-update=stream container — insert, delete, reset, reorder, and overflow a limited stream."
    >
      <:stage>
        <.stage title={"Stream — #{length(@item_ids)} item(s)"} align="start">
          <div id="items-stream" phx-update="stream" class="flex flex-wrap gap-2 content-start w-full">
            <.motion
              :for={{dom_id, item} <- @streams.items}
              id={dom_id}
              animate="zoom-in"
              exit={%{action: "zoom-out", duration: 350}}
              layout={true}
              stagger={80.0}
              class={"#{item.color} text-primary-content w-12 h-12 rounded-box flex items-center justify-center text-sm font-medium shadow"}
            >
              {item.label}
            </.motion>
          </div>
        </.stage>

        <.stage title="Limited stream (keeps last 8)" align="start">
          <div id="capped-stream" phx-update="stream" class="flex flex-wrap gap-2 content-start w-full">
            <.motion
              :for={{dom_id, item} <- @streams.capped}
              id={dom_id}
              animate="slide-left"
              exit={%{action: "fade", duration: 250}}
              layout={true}
              class="bg-neutral text-neutral-content w-12 h-12 rounded-box flex items-center justify-center text-sm font-medium shadow"
            >
              {item.label}
            </.motion>
          </div>
        </.stage>

        <.study_card study={@study} />
      </:stage>

      <:controls>
        <div class="rounded-box border border-base-300 p-4 space-y-3">
          <div class="text-sm font-semibold">Main stream</div>
          <div class="grid grid-cols-2 gap-2">
            <button type="button" phx-click="prepend" class="btn btn-primary btn-sm gap-1">
              <.icon name="hero-arrow-left" class="size-4" /> Prepend
            </button>
            <button type="button" phx-click="append" class="btn btn-primary btn-sm gap-1">
              Append <.icon name="hero-arrow-right" class="size-4" />
            </button>
          </div>
          <button type="button" phx-click="delete_random" class="btn btn-ghost btn-block btn-sm gap-2">
            <.icon name="hero-trash" class="size-4" /> Delete random
          </button>
          <button type="button" phx-click="reset" class="btn btn-ghost btn-block btn-sm gap-2">
            <.icon name="hero-arrow-path" class="size-4" /> Reset (5 items)
          </button>
        </div>

        <div class="rounded-box border border-base-300 p-4 space-y-3">
          <div class="text-sm font-semibold">Limited stream</div>
          <button type="button" phx-click="capped_add" class="btn btn-primary btn-block btn-sm gap-2">
            <.icon name="hero-plus" class="size-4" /> Add (limit 8)
          </button>
          <p class="text-xs opacity-50">
            Add past 8 and watch the oldest fall off the front — it should exit,
            not just disappear.
          </p>
        </div>

        <p class="text-xs opacity-50 leading-relaxed">
          Stagger is batch-relative: every single insert (prepend or append) plays
          immediately (delay 0), while a multi-item batch like Reset staggers the
          whole group 0, 80, 160ms… regardless of how many items are already on screen.
        </p>
      </:controls>
    </.playground_layout>
    """
  end
end
