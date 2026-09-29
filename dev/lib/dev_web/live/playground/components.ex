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
      <nav class="lg:w-60 shrink-0 border-b lg:border-b-0 lg:border-r border-base-300/70 p-5 lg:p-6">
        <a
          href="/"
          class="flex items-center gap-1.5 mb-8 text-sm font-medium text-base-content/50 hover:text-base-content"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Back to demo
        </a>
        <div class="text-xs font-medium text-base-content/40 mb-3 px-1">Playground</div>
        <ul class="flex lg:flex-col gap-1 flex-wrap">
          <li :for={s <- @sections}>
            <.link
              :if={s.built?}
              navigate={s.path}
              class={[
                "flex items-center gap-2.5 rounded-full px-3.5 py-2 text-sm transition-colors",
                if(@active == s.path,
                  do: "bg-base-100 text-base-content font-medium shadow-sm",
                  else: "text-base-content/60 hover:text-base-content hover:bg-base-200/60"
                )
              ]}
            >
              <.icon name={s.icon} class="size-4 shrink-0" />
              <span>{s.label}</span>
            </.link>
            <div
              :if={!s.built?}
              class="flex items-center gap-2.5 rounded-full px-3.5 py-2 text-sm text-base-content/30 cursor-not-allowed"
              title="Coming in a later build step"
            >
              <.icon name={s.icon} class="size-4 shrink-0" />
              <span>{s.label}</span>
              <span class="ml-auto rounded-full bg-base-200 px-2 py-0.5 text-[10px] font-medium text-base-content/50">
                soon
              </span>
            </div>
          </li>
        </ul>
        <a
          href="https://github.com/lucaspaulii/live_animate"
          target="_blank"
          rel="noopener"
          class="flex items-center gap-1.5 mt-8 px-1 text-sm font-medium text-base-content/50 hover:text-base-content"
        >
          <.icon name="hero-code-bracket" class="size-4" /> GitHub
        </a>
      </nav>

      <main class="flex-1 min-w-0 p-5 sm:p-8 lg:p-12">
        <header class="mb-8">
          <h1 class="text-3xl font-semibold tracking-tight sm:text-4xl">{@title}</h1>
          <p :if={@subtitle} class="text-base-content/60 mt-2 leading-relaxed">{@subtitle}</p>
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
      "rounded-3xl border border-base-300/70 bg-base-200/50 overflow-hidden",
      @class
    ]}>
      <div class="flex items-center justify-between px-5 py-3 border-b border-base-300/60">
        <span class="text-xs font-medium text-base-content/40">{@title}</span>
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
    <section class="rounded-3xl border border-base-300/70 bg-base-200/50 overflow-hidden">
      <div class="flex items-center justify-between px-5 py-3 border-b border-base-300/60">
        <span class="text-xs font-medium text-base-content/40">{@title}</span>
        <button
          type="button"
          phx-hook=".Copy"
          id="code-copy-btn"
          data-copy={@code}
          class="flex items-center gap-1 rounded-full px-3 py-1 text-xs font-medium text-base-content/60 hover:bg-base-200/60 hover:text-base-content"
        >
          <.icon name="hero-clipboard-document" class="size-3.5" /> <span>Copy</span>
        </button>
      </div>
      <pre class="overflow-x-auto p-5 font-mono text-sm leading-relaxed text-base-content/80"><code>{@code}</code></pre>
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
      <div class="flex justify-between text-sm mb-1.5">
        <span class="text-base-content/60">{@label}</span>
        <span class="font-mono tabular-nums font-medium text-base-content">{@value}{@unit}</span>
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
      <div class="text-sm text-base-content/60 mb-1.5">{@label}</div>
      <select name={@name} class="select select-sm select-bordered w-full rounded-full">
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
      <div class="text-sm text-base-content/60 mb-1.5">{@label}</div>
      <div class="flex w-full rounded-full bg-base-200 p-1">
        <label
          :for={opt <- @options}
          class={[
            "flex-1 cursor-pointer rounded-full px-3 py-1.5 text-center text-sm font-medium transition-colors",
            if(opt_value(opt) == to_string(@value),
              do: "bg-base-100 text-base-content shadow-sm",
              else: "text-base-content/60 hover:text-base-content"
            )
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

  defp opt_value({_label, value}), do: to_string(value)
  defp opt_value(value), do: to_string(value)
  defp opt_label({label, _value}), do: label
  defp opt_label(value), do: to_string(value)
end
