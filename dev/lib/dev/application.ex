defmodule DevWeb.App.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DevWeb.AppWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:dev, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DevWeb.App.PubSub},
      # Start a worker by calling: DevWeb.App.Worker.start_link(arg)
      # {DevWeb.App.Worker, arg},
      # Start to serve requests, typically the last entry
      DevWeb.AppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DevWeb.App.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DevWeb.AppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
