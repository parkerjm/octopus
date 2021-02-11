use Mix.Config

# Configure your database
config :octopus, Octopus.Repo,
  username: "postgres",
  password: "postgres",
  database: "octopus_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :octopus, Octopus.Repo.ListingsPortal,
  username: "postgres",
  password: "postgres",
  database: "api_edge_development",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :octopus, OctopusWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

# Watch static and templates for browser reloading.
config :octopus, OctopusWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/octopus_web/(live|views)/.*(ex)$",
      ~r"lib/octopus_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :octopus, :delighted,
  api_key: "mwQJ19JITSNbkwJsU0pjrpd2ztpeZw56",
  timeout_between_requests: 500

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
