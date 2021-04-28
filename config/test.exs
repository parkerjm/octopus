import Config

# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :octopus, Octopus.Repo,
  username: "postgres",
  password: "postgres",
  database: "octopus_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: :infinity

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :octopus, OctopusWeb.Endpoint,
  http: [port: 4002],
  server: false

config :octopus, Octopus.Repo.ListingsPortal, database: "api_edge_test"

config :logger, level: :warn
