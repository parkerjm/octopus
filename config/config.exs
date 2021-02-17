import Config

config :octopus, OctopusWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Zw07PK2VlpVHjvhuQnIyRGe8UmkqIFpVgmITC8qFE09Kz6FRmW7e7a9CZZ7Ym22H",
  render_errors: [view: OctopusWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Octopus.PubSub,
  live_view: [signing_salt: "v2oIwOvL"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

unique_opts = [
  period: 60 * 60 * 24,
  states: [:available, :scheduled, :executing]
]

config :octopus, Oban,
  repo: Octopus.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 3600},
    {Oban.Plugins.Cron,
     crontab: [{"*/15 * * * *", Octopus.Connector.Delighted, unique: unique_opts}]}
  ],
  queues: [default: 10]

config :octopus, ecto_repos: [Octopus.Repo]
config :octopus, delighted_client: Octopus.Client.Delighted
config :octopus, :delighted, api_key: "fake"
config :octopus, warehouse: Octopus.Sink.Warehouse
config :phoenix, :json_library, Jason
config :tesla, adapter: Tesla.Adapter.Hackney

import_config "#{Mix.env()}.exs"
