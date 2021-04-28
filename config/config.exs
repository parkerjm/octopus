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

config :octopus, :dashboard,
  username: "crown",
  password: "caliber"

config :octopus, ecto_repos: [Octopus.Repo]
config :phoenix, :json_library, Jason
config :tesla, adapter: Tesla.Adapter.Hackney

config :octopus, Oban,
  queues: false,
  plugins: false,
  repo: Octopus.Repo

config :octopus, :delighted,
  api_key: "fake_api_key",
  base_url: "https://api.delighted.com/v1/",
  timeout_between_requests: 0

config :octopus, :hubspot,
  api_key: "fake_api_key",
  base_url: "https://api.hubapi.com",
  timeout_between_requests: 0

config :octopus, :domo,
  base_url: "https://api.domo.com/v1/",
  username: "fake_user",
  password: "fake_pass",
  procurement_dataset_id: "fake_dataset_id",
  timeout_between_requests: 0

config :octopus, :ring_central,
  base_url: "https://platform.devtest.ringcentral.com/restapi/v1.0/",
  client_id: "fake_client_id",
  secret: "fake_secret",
  username: "fake_user",
  password: "fake_pass",
  timeout_between_requests: 0

import_config "#{Mix.env()}.exs"
