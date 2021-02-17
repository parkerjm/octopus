import Config

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

config :octopus, OctopusWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/octopus_web/(live|views)/.*(ex)$",
      ~r"lib/octopus_web/templates/.*(eex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :octopus, :delighted,
  api_key: "mwQJ19JITSNbkwJsU0pjrpd2ztpeZw56",
  timeout_between_requests: 500
