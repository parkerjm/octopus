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

config :octopus, ecto_repos: [Octopus.Repo]
config :phoenix, :json_library, Jason
config :tesla, adapter: Tesla.Adapter.Hackney

config :octopus, Oban,
  queues: false,
  plugins: false,
  repo: Octopus.Repo

config :octopus, :delighted,
  api_key: "fake",
  timeout_between_requests: 0

config :octopus, :hubspot, api_key: "fake"

config :octopus, :domo,
  username: "fake_user",
  password: "fake_pass",
  procurement_dataset_id: "fake",
  timeout_between_requests: 0

import_config "#{Mix.env()}.exs"
