import Config

config :octopus, OctopusWeb.Endpoint,
  url: [host: "octopus.crownandcaliber.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

config :logger, level: :info

# use runtime.exs
