defmodule LiveAnimateTest do
  use ExUnit.Case

  import Phoenix.Component
  import Phoenix.LiveViewTest

  defp render_motion(assigns_map) do
    assigns = Map.merge(%{__changed__: %{}}, assigns_map)
    rendered_to_string(LiveAnimate.motion(assigns))
  end

  defp decode_config(html) do
    [_, json] = Regex.run(~r/data-lm-config="([^"]*)"/, html)

    json
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> Jason.decode!()
  end

  # ── Basic rendering ──

  test "renders a div with hook and data-lm-config" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <LiveAnimate.motion id="test-1" animate="fade">
        <span>content</span>
      </LiveAnimate.motion>
      """)

    assert html =~ ~s(id="test-1")
    assert html =~ ~s(phx-hook="LiveAnimate")
    assert html =~ ~s(data-lm-config=)
    assert html =~ "<span>content</span>"
  end

  test "renders custom tag" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <LiveAnimate.motion id="test-2" tag="li">
        item
      </LiveAnimate.motion>
      """)

    assert html =~ "<li"
    assert html =~ "</li>"
  end

  test "passes through global attributes" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <LiveAnimate.motion id="test-3" class="my-class" data-foo="bar">
        content
      </LiveAnimate.motion>
      """)

    assert html =~ ~s(class="my-class")
    assert html =~ ~s(data-foo="bar")
  end

  # ── normalize_action with different input types ──

  test "normalize_action with string input produces action map" do
    html =
      render_motion(%{
        id: "str",
        tag: "div",
        name: nil,
        animate: "slide-up",
        exit: nil,
        hover: nil,
        tap: nil,
        drag: nil,
        in_view: nil,
        scroll: nil,
        duration: 300,
        delay: 0,
        layout: false,
        stagger: 0.0,
        rest: %{},
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "x" end}]
      })

    config = decode_config(html)
    assert config["animate"]["action"] == "slide-up"
    assert config["animate"]["duration"] == 300
    assert config["animate"]["delay"] == 0
  end

  test "normalize_action with atom input produces action map" do
    html =
      render_motion(%{
        id: "atom",
        tag: "div",
        name: nil,
        animate: :fade,
        exit: nil,
        hover: nil,
        tap: nil,
        drag: nil,
        in_view: nil,
        scroll: nil,
        duration: 300,
        delay: 0,
        layout: false,
        stagger: 0.0,
        rest: %{},
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "x" end}]
      })

    config = decode_config(html)
    assert config["animate"]["action"] == "fade"
  end

  test "normalize_action with map input merges extra keys" do
    html =
      render_motion(%{
        id: "map",
        tag: "div",
        name: nil,
        animate: nil,
        exit: nil,
        hover: nil,
        tap: nil,
        drag: nil,
        in_view: %{action: "slide-up", repeat: true, amount: 0.5},
        scroll: nil,
        duration: 300,
        delay: 0,
        layout: false,
        stagger: 0.0,
        rest: %{},
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "x" end}]
      })

    config = decode_config(html)
    assert config["in_view"]["action"] == "slide-up"
    assert config["in_view"]["repeat"] == true
    assert config["in_view"]["amount"] == 0.5
    assert config["in_view"]["duration"] == 300
  end

  test "normalize_action with boolean input (drag={true})" do
    html =
      render_motion(%{
        id: "bool",
        tag: "div",
        name: nil,
        animate: nil,
        exit: nil,
        hover: nil,
        tap: nil,
        drag: true,
        in_view: nil,
        scroll: nil,
        duration: 300,
        delay: 0,
        layout: false,
        stagger: 0.0,
        rest: %{},
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "x" end}]
      })

    config = decode_config(html)
    assert config["drag"]["enabled"] == true
  end

  # ── Config JSON structure ──

  test "data-lm-config contains expected keys for fully-specified motion" do
    html =
      render_motion(%{
        id: "full",
        tag: "div",
        name: nil,
        animate: "slide-up",
        exit: "fade",
        hover: "scale-up",
        tap: "press",
        drag: true,
        in_view: %{action: "fade", repeat: true},
        scroll: "fade",
        duration: 500,
        delay: 100,
        layout: true,
        stagger: 80.0,
        rest: %{},
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "x" end}]
      })

    config = decode_config(html)
    assert Map.has_key?(config, "animate")
    assert Map.has_key?(config, "exit")
    assert Map.has_key?(config, "hover")
    assert Map.has_key?(config, "tap")
    assert Map.has_key?(config, "drag")
    assert Map.has_key?(config, "in_view")
    assert Map.has_key?(config, "scroll")
    assert config["layout"] == true
    assert config["stagger"] == 80.0
  end

  # ── Duration / delay ──

  test "duration and delay defaults propagate to action" do
    html =
      render_motion(%{
        id: "defaults",
        tag: "div",
        name: nil,
        animate: "fade",
        exit: nil,
        hover: nil,
        tap: nil,
        drag: nil,
        in_view: nil,
        scroll: nil,
        duration: 300,
        delay: 0,
        layout: false,
        stagger: 0.0,
        rest: %{},
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "x" end}]
      })

    config = decode_config(html)
    assert config["animate"]["duration"] == 300
    assert config["animate"]["delay"] == 0
  end

  test "duration and delay overrides in map take precedence" do
    html =
      render_motion(%{
        id: "overrides",
        tag: "div",
        name: nil,
        animate: %{action: "fade", duration: 800, delay: 200},
        exit: nil,
        hover: nil,
        tap: nil,
        drag: nil,
        in_view: nil,
        scroll: nil,
        duration: 300,
        delay: 0,
        layout: false,
        stagger: 0.0,
        rest: %{},
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "x" end}]
      })

    config = decode_config(html)
    assert config["animate"]["duration"] == 800
    assert config["animate"]["delay"] == 200
  end

  # ── Name / view-transition-name ──

  test "name attribute sets inline view-transition-name style" do
    html =
      render_motion(%{
        id: "named",
        tag: "div",
        name: "hero-card",
        animate: "fade",
        exit: nil,
        hover: nil,
        tap: nil,
        drag: nil,
        in_view: nil,
        scroll: nil,
        duration: 300,
        delay: 0,
        layout: false,
        stagger: 0.0,
        rest: %{},
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "x" end}]
      })

    assert html =~ "view-transition-name: hero-card"
  end

  # ── Layout and stagger in config ──

  test "layout and stagger appear in config JSON" do
    html =
      render_motion(%{
        id: "ls",
        tag: "div",
        name: nil,
        animate: "fade",
        exit: nil,
        hover: nil,
        tap: nil,
        drag: nil,
        in_view: nil,
        scroll: nil,
        duration: 300,
        delay: 0,
        layout: true,
        stagger: 50.0,
        rest: %{},
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "x" end}]
      })

    config = decode_config(html)
    assert config["layout"] == true
    assert config["stagger"] == 50.0
  end

  # ── Reduced motion (respect_motion) ──

  defp base_assigns(extra) do
    Map.merge(
      %{
        id: "rm",
        tag: "div",
        name: nil,
        animate: "fade",
        exit: nil,
        hover: nil,
        tap: nil,
        drag: nil,
        in_view: nil,
        scroll: nil,
        duration: 300,
        delay: 0,
        layout: false,
        stagger: 0.0,
        rest: %{},
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "x" end}]
      },
      extra
    )
  end

  test "respect_motion omitted is absent from config (inherits global default)" do
    config = decode_config(render_motion(base_assigns(%{})))
    refute Map.has_key?(config, "respect_motion")
  end

  test "respect_motion false is serialized (opts out of reduced motion)" do
    config = decode_config(render_motion(base_assigns(%{respect_motion: false})))
    assert config["respect_motion"] == false
  end

  test "respect_motion true is serialized (forces honoring reduced motion)" do
    config = decode_config(render_motion(base_assigns(%{respect_motion: true})))
    assert config["respect_motion"] == true
  end

  # ── Exit with boolean (bare attribute) ──

  test "exit as bare attribute produces enabled config" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <LiveAnimate.motion id="exit-bool" exit>
        <span>bye</span>
      </LiveAnimate.motion>
      """)

    config = decode_config(html)
    assert config["exit"]["enabled"] == true
  end

  # ── Server-driven page transitions (use LiveAnimate + @transition) ──

  defmodule TransitionLive do
    use Phoenix.LiveView
    use LiveAnimate
    @transition "slide-left"
    def render(assigns), do: ~H""
  end

  defmodule PlainLive do
    use Phoenix.LiveView
    use LiveAnimate
    def render(assigns), do: ~H""
  end

  test "use LiveAnimate captures @transition via __lm_transition__/0" do
    assert TransitionLive.__lm_transition__() == "slide-left"
  end

  test "use LiveAnimate without @transition yields nil" do
    assert PlainLive.__lm_transition__() == nil
  end

  # ── @transition normalization (server → JS wire format) ──

  test "normalize_transition/1 turns a bare preset into a navigate-scoped map" do
    assert LiveAnimate.normalize_transition("slide-left") ==
             %{preset: "slide-left", apply_to: "navigate"}
  end

  test "normalize_transition/1 defaults apply_to to navigate for a map" do
    assert LiveAnimate.normalize_transition(%{preset: "fade", duration: 300}) ==
             %{preset: "fade", duration: 300, apply_to: "navigate"}
  end

  test "normalize_transition/1 keeps apply_to: :all and passes timing through" do
    assert LiveAnimate.normalize_transition(%{
             preset: "slide-left",
             duration: 300,
             easing: "ease-out",
             apply_to: :all
           }) ==
             %{preset: "slide-left", duration: 300, easing: "ease-out", apply_to: "all"}
  end

  test "normalize_transition/1 falls back to navigate for an unknown apply_to" do
    assert LiveAnimate.normalize_transition(%{preset: "fade", apply_to: :bogus}) ==
             %{preset: "fade", apply_to: "navigate"}
  end

  test "normalize_transition/1 drops unknown keys and preserves nil" do
    assert LiveAnimate.normalize_transition(%{preset: "fade", junk: 1}) ==
             %{preset: "fade", apply_to: "navigate"}

    assert LiveAnimate.normalize_transition(nil) == nil
  end

  test "normalize_transition/1 accepts valid easing forms (keyword, cubic-bezier, list)" do
    assert LiveAnimate.normalize_transition(%{preset: "fade", easing: "ease-in-out"}) ==
             %{preset: "fade", apply_to: "navigate", easing: "ease-in-out"}

    assert LiveAnimate.normalize_transition(%{
             preset: "fade",
             easing: "cubic-bezier(0.4, 0, 0.2, 1)"
           }) ==
             %{preset: "fade", apply_to: "navigate", easing: "cubic-bezier(0.4, 0, 0.2, 1)"}

    assert LiveAnimate.normalize_transition(%{preset: "fade", easing: [0.4, 0, 0.2, 1]}) ==
             %{preset: "fade", apply_to: "navigate", easing: [0.4, 0, 0.2, 1]}
  end

  test "normalize_transition/1 drops a CSS-injecting easing string" do
    assert LiveAnimate.normalize_transition(%{
             preset: "fade",
             easing: "ease; } body { background: url(https://evil/?leak) "
           }) ==
             %{preset: "fade", apply_to: "navigate"}

    # A cubic-bezier with a non-numeric arg is not the strict form → dropped.
    assert LiveAnimate.normalize_transition(%{
             preset: "fade",
             easing: "cubic-bezier(0,0,1,1); } x{y:z"
           }) ==
             %{preset: "fade", apply_to: "navigate"}
  end

  test "normalize_transition/1 keeps a numeric duration but drops a non-numeric one" do
    assert LiveAnimate.normalize_transition(%{preset: "fade", duration: 250}) ==
             %{preset: "fade", apply_to: "navigate", duration: 250}

    assert LiveAnimate.normalize_transition(%{preset: "fade", duration: "300ms; } x{}"}) ==
             %{preset: "fade", apply_to: "navigate"}

    assert LiveAnimate.normalize_transition(%{preset: "fade", duration: -5}) ==
             %{preset: "fade", apply_to: "navigate"}
  end

  test "use LiveAnimate registers the LiveAnimate on_mount hook" do
    hooks = TransitionLive.__live__().lifecycle.mount
    on_mount_fun = Function.capture(LiveAnimate, :on_mount, 4)
    assert Enum.any?(hooks, fn hook -> hook.function == on_mount_fun end)
  end

  test "on_mount assigns nothing and continues for a disconnected socket" do
    # Disconnected (dead-render) mount: no push, just continue.
    socket = %Phoenix.LiveView.Socket{view: TransitionLive}
    assert {:cont, ^socket} = LiveAnimate.on_mount(:default, %{}, %{}, socket)
  end
end
