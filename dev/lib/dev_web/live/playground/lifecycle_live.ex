defmodule DevWeb.AppWeb.Playground.LifecycleLive do
  @moduledoc """
  Lifecycle harness: the production bug-catcher. Reproduces two of the highest-
  risk LiveView integration cases before a team builds on the lib:

    * destroyed() cleanup / leaks — spawn many hook-heavy elements, destroy them,
      and watch whether the FLIP-tracking map and mounted-hook count return to
      baseline across cycles.
    * exit animation race — batch-remove elements and re-add an element with the
      same id mid-exit.

  See `demo-playground-plan.md` §4.2 and §4.3.
  """
  use DevWeb.AppWeb, :live_view

  import DevWeb.AppWeb.Playground.Components
  alias DevWeb.AppWeb.Playground.Studies

  @batch 24

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Lifecycle harness",
       batch: @batch,
       leak_study: Studies.get(:destroy_leak),
       exit_study: Studies.get(:exit_race),
       leak_gen: 0,
       leak_ids: [],
       cycles: 0,
       exit_items: [],
       exit_next_id: 1,
       ghost_present: false
     )}
  end

  # ── Leak harness ──────────────────────────────────────────────────────────

  @impl true
  def handle_event("spawn_leak", _params, socket) do
    gen = socket.assigns.leak_gen + 1
    ids = Enum.map(1..@batch, &{gen, &1})
    {:noreply, assign(socket, leak_gen: gen, leak_ids: ids)}
  end

  @impl true
  def handle_event("clear_leak", _params, socket) do
    {:noreply, socket |> assign(leak_ids: []) |> update(:cycles, &(&1 + 1))}
  end

  # ── Exit-race harness ─────────────────────────────────────────────────────

  @impl true
  def handle_event("add_exit", _params, socket) do
    start = socket.assigns.exit_next_id
    new_items = Enum.map(start..(start + 9), &%{id: &1})

    {:noreply,
     socket
     |> update(:exit_items, &(&1 ++ new_items))
     |> assign(exit_next_id: start + 10)}
  end

  @impl true
  def handle_event("remove_all_exit", _params, socket) do
    {:noreply, assign(socket, exit_items: [])}
  end

  @impl true
  def handle_event("readd_ghost", _params, socket) do
    # Remove now; re-add 50ms later — i.e. while the exit animation is still
    # playing — to reproduce the same-id-mid-exit race.
    Process.send_after(self(), :readd_ghost, 50)
    {:noreply, assign(socket, ghost_present: false)}
  end

  @impl true
  def handle_event("add_ghost", _params, socket) do
    {:noreply, assign(socket, ghost_present: true)}
  end

  @impl true
  def handle_info(:readd_ghost, socket), do: {:noreply, assign(socket, ghost_present: true)}

  # A hook-heavy element: hover listeners + FLIP tracking on every element, plus
  # an IntersectionObserver (in_view) or a loop timer (animate loop) alternating,
  # so both cleanup paths are exercised.
  defp leak_extra_attrs({_gen, i}) when rem(i, 2) == 0, do: %{in_view: "fade"}
  defp leak_extra_attrs(_id), do: %{animate: %{action: "pulse", loop: true, interval: 900}}

  @impl true
  def render(assigns) do
    ~H"""
    <.playground_layout
      active="/playground/lifecycle"
      title="Lifecycle harness"
      subtitle="Reproduce the LiveView integration bugs that break animation hooks — before the team hits them."
    >
      <:stage>
        <%!-- Leak metrics; the colocated hook polls the lib's internal state. --%>
        <section
          id="leak-metrics"
          phx-hook=".Metrics"
          class="rounded-box border border-base-300 p-4 grid grid-cols-3 gap-4 text-center"
        >
          <div>
            <div class="text-3xl font-bold font-mono tabular-nums" id="metric-layout">–</div>
            <div class="text-xs opacity-60 mt-1">FLIP-tracked<br />(_layoutElements.size)</div>
          </div>
          <div>
            <div class="text-3xl font-bold font-mono tabular-nums" id="metric-mounted">–</div>
            <div class="text-xs opacity-60 mt-1">Mounted hooks<br />([data-lm-config])</div>
          </div>
          <div>
            <div class="text-3xl font-bold font-mono tabular-nums">{@cycles}</div>
            <div class="text-xs opacity-60 mt-1">Spawn/clear<br />cycles</div>
          </div>
          <%!-- Fixed single-line height (not min-height) so the JS-filled verdict
                can never grow the panel and shift the stages below. Text is kept
                to one line (nowrap) for the same reason. --%>
          <div id="leak-verdict" class="col-span-3 text-sm font-medium h-6 flex items-center justify-center whitespace-nowrap overflow-hidden"></div>
          <script :type={Phoenix.LiveView.ColocatedHook} name=".Metrics">
            export default {
              mounted() { this.start() },
              start() {
                const poll = () => {
                  const la = window.LiveAnimate
                  const layout = (la && la._layoutElements) ? la._layoutElements.size : "n/a"
                  const mounted = document.querySelectorAll("[data-lm-config]").length
                  const set = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v }
                  set("metric-layout", layout)
                  set("metric-mounted", mounted)
                  // Verdict: after a clear, FLIP-tracked should settle back to the
                  // number of layout elements still on the page (0 here). A value
                  // that keeps climbing across cycles indicates a leak.
                  const verdict = document.getElementById("leak-verdict")
                  if (verdict) {
                    // Keep the fixed-height/nowrap layout classes constant; only
                    // swap the color, so the panel height never changes.
                    const base = "col-span-3 text-sm font-medium h-6 flex items-center justify-center whitespace-nowrap overflow-hidden"
                    let msg, color
                    if (layout === "n/a") {
                      msg = "window.LiveAnimate not exposed"; color = "opacity-50"
                    } else if (layout === 0) {
                      msg = "✓ FLIP tracking clean (0)"; color = "text-success"
                    } else {
                      msg = `${layout} tracked · clears to 0 on Clear all`; color = "opacity-70"
                    }
                    verdict.textContent = msg
                    verdict.className = `${base} ${color}`
                  }
                }
                poll()
                this._timer = setInterval(poll, 500)
              },
              destroyed() { if (this._timer) clearInterval(this._timer) }
            }
          </script>
        </section>

        <.stage title={"Leak harness — #{length(@leak_ids)} live element(s)"} align="start">
          <div class="w-full space-y-3">
            <%!-- Kept in the DOM (invisible when empty) rather than :if'd out, so
                  its height is reserved and toggling data never reflows the page —
                  a reflow mid-exit would corrupt the lib's exit position measurement. --%>
            <div class={["flex flex-wrap gap-4 justify-center text-xs opacity-70", @leak_ids == [] && "invisible"]}>
              <span class="flex items-center gap-1.5">
                <span class="w-3 h-3 rounded bg-accent inline-block"></span> pulse loop (setTimeout timer)
              </span>
              <span class="flex items-center gap-1.5">
                <span class="w-3 h-3 rounded bg-info inline-block"></span> in_view fade (IntersectionObserver)
              </span>
            </div>
            <div class="h-56 overflow-y-auto">
              <div class="flex flex-wrap gap-2 justify-center">
                <.motion
                  :for={{gen, i} = id <- @leak_ids}
                  id={"leak-#{gen}-#{i}"}
                  hover="scale-up"
                  layout={true}
                  {leak_extra_attrs(id)}
                  class={[
                    "text-xs w-10 h-10 rounded flex items-center justify-center shadow",
                    (rem(i, 2) == 0 && "bg-info text-info-content") || "bg-accent text-accent-content"
                  ]}
                >
                  {i}
                </.motion>
              </div>
            </div>
          </div>
        </.stage>

        <.study_card study={@leak_study} />

        <%!-- Exit-race harness --%>
        <.stage title={"Exit-race harness — #{length(@exit_items)} item(s)"} align="start">
          <div class="w-full h-56 overflow-y-auto">
            <div class="flex flex-wrap gap-2 justify-center items-start content-start">
              <.motion
                :for={item <- @exit_items}
                id={"exit-item-#{item.id}"}
                animate="zoom-in"
                exit={%{action: "zoom-out", duration: 400}}
                layout={true}
                class="bg-info text-info-content w-12 h-12 rounded-box flex items-center justify-center text-xs font-medium shadow"
              >
                {item.id}
              </.motion>

              <.motion
                :if={@ghost_present}
                id="exit-ghost"
                animate="slide-up"
                exit={%{action: "slide-left", duration: 500}}
                class="bg-error text-error-content w-20 h-12 rounded-box flex items-center justify-center text-xs font-medium shadow"
              >
                ghost
              </.motion>
            </div>
          </div>
        </.stage>

        <.study_card study={@exit_study} />
      </:stage>

      <:controls>
        <div class="rounded-box border border-base-300 p-4 space-y-3">
          <div class="text-sm font-semibold">Leak harness</div>
          <button type="button" phx-click="spawn_leak" class="btn btn-primary btn-block btn-sm gap-2">
            <.icon name="hero-plus" class="size-4" /> Spawn {@batch}
          </button>
          <button type="button" phx-click="clear_leak" class="btn btn-ghost btn-block btn-sm gap-2">
            <.icon name="hero-trash" class="size-4" /> Clear all
          </button>
          <p class="text-xs opacity-50">
            Spawn then Clear, several times. Watch that FLIP-tracked returns to 0
            and nothing climbs across cycles.
          </p>
        </div>

        <div class="rounded-box border border-base-300 p-4 space-y-3">
          <div class="text-sm font-semibold">Exit-race harness</div>
          <button type="button" phx-click="add_exit" class="btn btn-primary btn-block btn-sm gap-2">
            <.icon name="hero-plus" class="size-4" /> Add 10
          </button>
          <button type="button" phx-click="remove_all_exit" class="btn btn-ghost btn-block btn-sm gap-2">
            <.icon name="hero-bolt" class="size-4" /> Remove all (fast)
          </button>
          <div class="divider my-1 text-xs opacity-50">same id</div>
          <button
            :if={not @ghost_present}
            type="button"
            phx-click="add_ghost"
            class="btn btn-ghost btn-block btn-sm"
          >
            Add ghost
          </button>
          <button
            :if={@ghost_present}
            type="button"
            phx-click="readd_ghost"
            class="btn btn-warning btn-block btn-sm gap-2"
          >
            <.icon name="hero-arrow-path" class="size-4" /> Remove + re-add (50ms)
          </button>
          <p class="text-xs opacity-50">
            After Remove all, every item should animate out with no leftover
            ghosts. Re-add same id should animate in cleanly.
          </p>
        </div>
      </:controls>
    </.playground_layout>
    """
  end
end
