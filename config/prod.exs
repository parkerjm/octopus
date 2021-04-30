import Config

config :octopus, OctopusWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

config :logger, level: :info

unique_opts = [
  period: :infinity,
  states: [:available, :scheduled, :executing, :retryable]
]

shared_crontab = [
  {"*/15 * * * *", Octopus.Connector.Delighted, max_attempts: 1, unique: unique_opts},
  {"*/15 * * * *", Octopus.Connector.RingCentral, max_attempts: 1, unique: unique_opts},
]

production_crontab = [
  {"*/20 * * * *", Octopus.Connector.Domo, max_attempts: 1, unique: unique_opts}
  {"*/30 * * * *", Octopus.Connector.Hubspot, max_attempts: 1, unique: unique_opts}
]

crontab =
  if System.get_env("APP_ENV") == "production" do
    shared_crontab ++ production_crontab
  else
    shared_crontab
  end

config :octopus, Oban,
  repo: Octopus.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 3600},
    {Oban.Plugins.Cron, crontab: crontab}
  ],
  queues: [default: 10]

# use runtime.exs for loading data from env
