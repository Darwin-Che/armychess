defmodule Armychess.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ArmychessWeb.Telemetry,
      Armychess.Repo,
      {DNSCluster, query: Application.get_env(:armychess, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Armychess.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Armychess.Finch},
      # Start a worker by calling: Armychess.Worker.start_link(arg)
      # {Armychess.Worker, arg},
      # Start to serve requests, typically the last entry
      ArmychessWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Armychess.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ArmychessWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
