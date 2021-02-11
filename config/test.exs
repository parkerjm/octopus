use Mix.Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :octopus, Octopus.Repo,
  username: "postgres",
  password: "postgres",
  database: "octopus_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :octopus, OctopusWeb.Endpoint,
  http: [port: 4002],
  server: false

config :octopus, Octopus.Repo.ListingsPortal, database: "api_edge_test"

config :octopus, Oban, queues: false, plugins: false

config :octopus, delighted_client: Octopus.Client.DelightedMock
config :octopus, :delighted, timeout_between_requests: 0
config :octopus, warehouse: Octopus.Sink.WarehouseMock

config :logger, level: :warn

config :tesla, adapter: Tesla.Mock
