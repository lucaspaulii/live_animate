defmodule DevWeb.AppWeb.Router do
  use DevWeb.AppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DevWeb.AppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DevWeb.AppWeb do
    pipe_through :browser

    live "/", DemoLive

    # Page-transition showcase — one route per preset (see TransitionDemo).
    live "/transitions/fade", TransitionDemo.Fade
    live "/transitions/blur", TransitionDemo.Blur
    live "/transitions/slide-left", TransitionDemo.SlideLeft
    live "/transitions/slide-right", TransitionDemo.SlideRight
    live "/transitions/slide-up", TransitionDemo.SlideUp
    live "/transitions/slide-down", TransitionDemo.SlideDown
    live "/playground", PlaygroundLive
    live "/playground/presets", Playground.PresetsLive
    live "/playground/transitions", Playground.TransitionsLive
    live "/playground/gestures", Playground.GesturesLive
    live "/playground/layout", Playground.LayoutLive
    live "/playground/lifecycle", Playground.LifecycleLive
    live "/playground/streams", Playground.StreamsLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", DevWeb.AppWeb do
  #   pipe_through :api
  # end
end
