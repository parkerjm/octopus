import Config

config :octopus, OctopusWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

config :logger, level: :info

unique_opts = [
  period: 60 * 60 * 24,
  states: [:available, :scheduled, :executing]
]

config :octopus, Oban,
  repo: Octopus.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 3600},
    {Oban.Plugins.Cron,
     crontab: [
       {"*/15 * * * *", Octopus.Connector.Delighted, unique: unique_opts},
       {"*/22 * * * *", Octopus.Connector.Domo, unique: unique_opts}
     ]}
  ],
  queues: [default: 10]

# use runtime.exs
