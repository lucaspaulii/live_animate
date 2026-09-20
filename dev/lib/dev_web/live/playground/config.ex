defmodule DevWeb.AppWeb.Playground.Config do
  @moduledoc """
  Shared, mostly-pure helpers for the playground sections: turning control state
  into `<.motion>` config maps, generating copy-paste HEEx, and parsing
  `phx-change` params back into typed socket assigns.

  Centralizing these keeps every section consistent (a team using the lib should
  see the same code shape everywhere) and keeps each LiveView small.
  """
  import Phoenix.Component, only: [assign: 3]

  @presets %{
    entrance:
      ~w(fade blur slide-up slide-down slide-left slide-right zoom-in zoom-out drop flip-x flip-y),
    gesture: ~w(scale-up scale-down press lift tilt-left tilt-right),
    keyframe: ~w(shake bounce pulse wiggle spin ping rubber-band float highlight)
  }

  @ease_options [
    {"ease-in-out", "ease_in_out"},
    {"ease-in", "ease_in"},
    {"ease-out", "ease_out"},
    {"linear", "linear"}
  ]

  @doc "Presets grouped by category (`:entrance`, `:gesture`, `:keyframe`)."
  def presets, do: @presets

  @doc "All preset names, flattened."
  def all_presets, do: @presets |> Map.values() |> List.flatten()

  @doc "The category atom for a preset name, or `:entrance` if unknown."
  def category_of(preset) do
    Enum.find_value(@presets, :entrance, fn {cat, names} ->
      if preset in names, do: cat
    end)
  end

  @doc "Which `<.motion>` key a preset is best previewed through."
  def preview_key(preset) do
    case category_of(preset) do
      :gesture -> :hover
      _ -> :animate
    end
  end

  @doc "Options for the tween easing select."
  def ease_options, do: @ease_options

  @doc "Default control state shared by tuner-style sections."
  def default_state do
    %{
      transition_type: "spring",
      stiffness: 100,
      damping: 10,
      mass: 1.0,
      duration: 400,
      delay: 0,
      ease: "ease_in_out"
    }
  end

  @doc "Builds the transition map for a `<.motion>` animation config from control state."
  def transition_config(%{transition_type: "spring"} = s),
    do: %{type: "spring", stiffness: s.stiffness, damping: s.damping, mass: s.mass}

  def transition_config(%{transition_type: "tween"} = s),
    do: %{type: "tween", ease: s.ease, duration: s.duration}

  @doc "The inline `%{...}` transition source string used inside generated HEEx."
  def transition_inline(%{transition_type: "spring"} = s),
    do: "type: \"spring\", stiffness: #{s.stiffness}, damping: #{s.damping}, mass: #{fmt_float(s.mass)}"

  def transition_inline(%{transition_type: "tween"} = s),
    do: "type: \"tween\", ease: \"#{s.ease}\", duration: #{s.duration}"

  @doc """
  Generates copy-paste HEEx for a `<.motion>` element. Mirrors the real preview
  element: `class` and `delay` live on the component itself.

  Options:
    * `:key` — the animation attr, defaults to `:animate`
    * `:delay` — top-level delay in ms (omitted when 0)
    * `:class` — CSS classes on the component
    * `:content` — inner text
  """
  def motion_code(preset, state, opts \\ []) do
    key = Keyword.get(opts, :key, :animate)
    delay = Keyword.get(opts, :delay, 0)
    class = Keyword.get(opts, :class, "rounded-box bg-primary text-primary-content px-8 py-6")
    content = Keyword.get(opts, :content, "Content")
    delay_attr = if delay > 0, do: "\n      delay={#{delay}}", else: ""

    """
    <.motion
      id="my-element"
      #{key}={%{
        action: "#{preset}",
        transition: %{#{transition_inline(state)}}
      }}#{delay_attr}
      class="#{class}"
    >
      #{content}
    </.motion>\
    """
  end

  # ── phx-change param parsing ──────────────────────────────────────────────

  @doc "Assigns a raw string param if present."
  def put_str(socket, params, key, assign_key) do
    case Map.get(params, key) do
      nil -> socket
      val -> assign(socket, assign_key, val)
    end
  end

  @doc "Parses and assigns an integer param, keeping the current value on error."
  def put_int(socket, params, key, assign_key) do
    case Map.get(params, key) do
      nil -> socket
      val -> assign(socket, assign_key, parse_int(val, Map.fetch!(socket.assigns, assign_key)))
    end
  end

  @doc "Parses and assigns a float param, keeping the current value on error."
  def put_float(socket, params, key, assign_key) do
    case Map.get(params, key) do
      nil -> socket
      val -> assign(socket, assign_key, parse_float(val, Map.fetch!(socket.assigns, assign_key)))
    end
  end

  @doc "Applies the standard transition controls (type + spring/tween params + delay)."
  def put_transition_controls(socket, params) do
    socket
    |> put_str(params, "transition_type", :transition_type)
    |> put_str(params, "ease", :ease)
    |> put_int(params, "stiffness", :stiffness)
    |> put_int(params, "damping", :damping)
    |> put_float(params, "mass", :mass)
    |> put_int(params, "duration", :duration)
    |> put_int(params, "delay", :delay)
  end

  defp parse_int(val, default) do
    case Integer.parse(to_string(val)) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_float(val, default) do
    case Float.parse(to_string(val)) do
      {f, _} -> f
      :error -> default
    end
  end

  @doc "Formats a float for display/code (2 decimals)."
  def fmt_float(f) when is_float(f), do: :erlang.float_to_binary(f, decimals: 2)
  def fmt_float(n), do: to_string(n)
end
