defmodule LiveAnimate.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/lucaspaulii/live_animate"
  @demo_url "https://live-animate-demo.fly.dev"

  def project do
    [
      app: :live_animate,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Declarative animations for Phoenix LiveView",
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.1"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:makeup_elixir, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Lucas Pauli"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url, "Demo" => @demo_url},
      files:
        ~w(lib assets/js/live_animate.js assets/js/presets.js assets/css package.json mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "LiveAnimate",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      source_ref: "v#{@version}"
    ]
  end
end
