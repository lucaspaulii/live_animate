defmodule DevWeb.AppWeb.Playground.Components do
  @moduledoc """
  Shared UI building blocks for the LiveAnimate playground.

  The playground is both an interactive explorer for `<.motion>` and a
  production edge-case harness (see `demo-playground-plan.md`). These components
  provide the common shell so each section stays small and focused.
  """
  use DevWeb.AppWeb, :html

  # `built?: false` sections render as disabled "soon" items so the nav shows the
  # full roadmap without producing dead links. Flip to `true` as each is built.
  @sections [
    %{path: "/playground", label: "Overview", icon: "hero-home", built?: true},
    %{path: "/playground/presets", label: "Presets", icon: "hero-sparkles", built?: true},
    %{path: "/playground/transitions", label: "Transitions", icon: "hero-adjustments-horizontal", built?: true},
    %{path: "/playground/gestures", label: "Gestures", icon: "hero-cursor-arrow-rays", built?: true},
    %{path: "/playground/layout", label: "Layout / FLIP", icon: "hero-squares-2x2", built?: true},
    %{path: "/playground/lifecycle", label: "Lifecycle harness", icon: "hero-bug-ant", built?: true},
    %{path: "/playground/streams", label: "Streams", icon: "hero-queue-list", built?: true},
    %{path: "/playground/navigation", label: "Navigation", icon: "hero-arrows-right-left", built?: false}
  ]

  @doc "The sections nav is rendered from this list; sections with `built?: false` are shown disabled."
  def sections, do: @sections

  attr :active, :string, required: true, doc: "current section path, used to highlight the nav"
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :stage, doc: "the animated preview area"
  slot :controls, doc: "the right-hand control panel"
  slot :inner_block, doc: "free-form content below the stage/controls grid"

  @doc "Two/three-pane playground shell: left nav, center stage, right controls."
  def playground_layout(assigns) do
    assigns = assign(assigns, :sections, sections())

    ~H"""
    <div class="min-h-screen flex flex-col lg:flex-row">
      <nav class="lg:w-56 shrink-0 border-b lg:border-b-0 lg:border-r border-base-300 p-4">
        <a href="/" class="flex items-center gap-2 mb-6 text-sm opacity-70 hover:opacity-100">
          <.icon name="hero-arrow-left" class="size-4" /> Back to demo
        </a>
        <div class="text-xs font-semibold uppercase tracking-wide opacity-50 mb-2">Playground</div>
        <ul class="flex lg:flex-col gap-1 flex-wrap">
          <li :for={s <- @sections}>
            <.link
              :if={s.built?}
              navigate={s.path}
              class={[
                "flex items-center gap-2 rounded-lg px-3 py-2 text-sm transition-colors",
                if(@active == s.path,
                  do: "bg-primary/15 text-primary font-medium",
                  else: "hover:bg-base-200"
                )
              ]}
            >
              <.icon name={s.icon} class="size-4 shrink-0" />
              <span>{s.label}</span>
            </.link>
            <div
              :if={!s.built?}
              class="flex items-center gap-2 rounded-lg px-3 py-2 text-sm opacity-40 cursor-not-allowed"
              title="Coming in a later build step"
            >
              <.icon name={s.icon} class="size-4 shrink-0" />
              <span>{s.label}</span>
              <span class="ml-auto text-[10px] uppercase tracking-wide badge badge-ghost badge-sm">soon</span>
            </div>
          </li>
        </ul>
      </nav>

      <main class="flex-1 min-w-0 p-4 sm:p-6 lg:p-8">
        <header class="mb-6">
          <h1 class="text-2xl font-bold">{@title}</h1>
          <p :if={@subtitle} class="text-base-content/60 mt-1">{@subtitle}</p>
        </header>

        <div class="grid grid-cols-1 xl:grid-cols-[1fr_20rem] gap-6 items-start">
          <div class="min-w-0 space-y-6">
            {render_slot(@stage)}
          </div>
          <aside :if={@controls != []} class="xl:sticky xl:top-6 space-y-4">
            {render_slot(@controls)}
          </aside>
        </div>

        <div :if={@inner_block != []} class="mt-8">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>
    """
  end

  attr :title, :string, default: "Stage"
  attr :class, :string, default: nil

  attr :align, :string,
    default: "center",
    values: ~w(center start),
    doc: "\"center\" (single preview) or \"start\" (top-aligned; use for growing lists to avoid vertical shift)"

  slot :inner_block, required: true

  @doc "A neutral, grid-backed area where animated elements render so motion reads clearly."
  def stage(assigns) do
    ~H"""
    <section class={[
      "rounded-box border border-base-300 bg-base-200/40 overflow-hidden",
      @class
    ]}>
      <div class="flex items-center justify-between px-4 py-2 border-b border-base-300 bg-base-200/60">
        <span class="text-xs font-medium uppercase tracking-wide opacity-60">{@title}</span>
      </div>
      <div
        class={[
          "relative min-h-64 flex justify-center p-8",
          (@align == "start" && "items-start") || "items-center"
        ]}
        style="background-image: radial-gradient(circle, color-mix(in oklch, currentColor 8%, transparent) 1px, transparent 1px); background-size: 16px 16px;"
      >
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  attr :code, :string, required: true, doc: "the HEEx source to display and copy"
  attr :title, :string, default: "Generated HEEx"

  @doc """
  Shows generated HEEx with a copy-to-clipboard button. This is the core of the
  playground: it maps \"what I tuned\" to \"code I can paste\".
  """
  def code_panel(assigns) do
    ~H"""
    <section class="rounded-box border border-base-300 overflow-hidden">
      <div class="flex items-center justify-between px-4 py-2 border-b border-base-300 bg-base-200/60">
        <span class="text-xs font-medium uppercase tracking-wide opacity-60">{@title}</span>
        <button
          type="button"
          phx-hook=".Copy"
          id="code-copy-btn"
          data-copy={@code}
          class="btn btn-xs btn-ghost gap-1"
        >
          <.icon name="hero-clipboard-document" class="size-3.5" /> Copy
        </button>
      </div>
      <pre class="overflow-x-auto p-4 text-sm leading-relaxed bg-base-300/30"><code>{@code}</code></pre>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".Copy">
        export default {
          mounted() {
            this.el.addEventListener("click", () => {
              const text = this.el.dataset.copy || ""
              navigator.clipboard.writeText(text).then(() => {
                const label = this.el.querySelector("span") || this.el
                const original = label.textContent
                label.textContent = "Copied!"
                setTimeout(() => { label.textContent = original }, 1200)
              }).catch(() => {})
            })
          },
          updated() {
            // data-copy is re-rendered on every tweak; nothing else to do.
          }
        }
      </script>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :any, required: true
  attr :min, :any, required: true
  attr :max, :any, required: true
  attr :step, :any, default: 1
  attr :unit, :string, default: ""

  @doc "A labeled range slider wired for `phx-change` inside a form."
  def slider(assigns) do
    ~H"""
    <label class="block">
      <div class="flex justify-between text-sm mb-1">
        <span class="opacity-70">{@label}</span>
        <span class="font-mono tabular-nums">{@value}{@unit}</span>
      </div>
      <input
        type="range"
        name={@name}
        value={@value}
        min={@min}
        max={@max}
        step={@step}
        class="range range-primary range-xs w-full"
      />
    </label>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :any, required: true
  attr :options, :list, required: true, doc: "list of {label, value} or plain values"

  @doc "A labeled select wired for `phx-change`."
  def select_control(assigns) do
    ~H"""
    <label class="block">
      <div class="text-sm opacity-70 mb-1">{@label}</div>
      <select name={@name} class="select select-sm select-bordered w-full">
        <option :for={opt <- @options} value={opt_value(opt)} selected={opt_value(opt) == to_string(@value)}>
          {opt_label(opt)}
        </option>
      </select>
    </label>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :any, required: true
  attr :options, :list, required: true

  @doc "A segmented (radio-button-group) control for a small set of mutually exclusive values."
  def segmented(assigns) do
    ~H"""
    <div>
      <div class="text-sm opacity-70 mb-1">{@label}</div>
      <div class="join w-full">
        <label
          :for={opt <- @options}
          class={[
            "btn btn-sm join-item flex-1 font-normal",
            if(opt_value(opt) == to_string(@value), do: "btn-primary", else: "btn-ghost bg-base-200")
          ]}
        >
          <input
            type="radio"
            name={@name}
            value={opt_value(opt)}
            checked={opt_value(opt) == to_string(@value)}
            class="hidden"
          />
          {opt_label(opt)}
        </label>
      </div>
    </div>
    """
  end

  attr :study, :map, required: true, doc: "a map from DevWeb.AppWeb.Playground.Studies"

  @doc "Renders an edge-case study card: what it is, why risky, how to trigger, expected vs failure."
  def study_card(assigns) do
    ~H"""
    <section class="rounded-box border border-warning/40 bg-warning/5 overflow-hidden">
      <div class="flex items-center gap-2 px-4 py-2 border-b border-warning/30 bg-warning/10">
        <.icon name="hero-bug-ant" class="size-4 text-warning" />
        <span class="text-sm font-semibold">{@study.title}</span>
      </div>
      <dl class="p-4 grid sm:grid-cols-2 gap-x-6 gap-y-3 text-sm">
        <div>
          <dt class="text-xs font-semibold uppercase tracking-wide opacity-50">What</dt>
          <dd class="mt-0.5 opacity-80">{@study.what}</dd>
        </div>
        <div>
          <dt class="text-xs font-semibold uppercase tracking-wide opacity-50">Why risky</dt>
          <dd class="mt-0.5 opacity-80">{@study.why_risky}</dd>
        </div>
        <div>
          <dt class="text-xs font-semibold uppercase tracking-wide opacity-50">How to trigger</dt>
          <dd class="mt-0.5 opacity-80">{@study.how_to_trigger}</dd>
        </div>
        <div>
          <dt class="text-xs font-semibold uppercase tracking-wide text-success/70">Expected</dt>
          <dd class="mt-0.5 opacity-80">{@study.expected}</dd>
        </div>
        <div class="sm:col-span-2">
          <dt class="text-xs font-semibold uppercase tracking-wide text-error/70">Failure looks like</dt>
          <dd class="mt-0.5 opacity-80">{@study.failure}</dd>
        </div>
        <div :if={@study[:code_refs]} class="sm:col-span-2">
          <dt class="text-xs font-semibold uppercase tracking-wide opacity-50">Code</dt>
          <dd class="mt-0.5 flex flex-wrap gap-2">
            <code :for={ref <- @study.code_refs} class="text-xs bg-base-300/50 rounded px-1.5 py-0.5">{ref}</code>
          </dd>
        </div>
      </dl>
    </section>
    """
  end

  defp opt_value({_label, value}), do: to_string(value)
  defp opt_value(value), do: to_string(value)
  defp opt_label({label, _value}), do: label
  defp opt_label(value), do: to_string(value)
end
