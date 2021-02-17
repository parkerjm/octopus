defmodule Octopus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Octopus.Repo,
      OctopusWeb.Telemetry,
      {Phoenix.PubSub, name: Octopus.PubSub},
      OctopusWeb.Endpoint,
      # Octopus.Repo.ListingsPortal,
      {Oban, oban_config()}
    ]

    :telemetry.attach_many("oban-logger", oban_events(), &Octopus.ObanLogger.handle_event/4, [])
    :ok = Oban.Telemetry.attach_default_logger()

    opts = [strategy: :one_for_one, name: Octopus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    OctopusWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp oban_config do
    Application.get_env(:octopus, Oban)
  end

  defp oban_events do
    [
      [:oban, :job, :start],
      [:oban, :job, :stop],
      [:oban, :job, :exception]
    ]
  end
end
