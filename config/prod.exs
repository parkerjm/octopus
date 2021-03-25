import Config

config :octopus, OctopusWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

config :logger, level: :info

# use runtime.exs
