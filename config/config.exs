# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :octopus,
  ecto_repos: [Octopus.Repo]

# Configures the endpoint
config :octopus, OctopusWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Zw07PK2VlpVHjvhuQnIyRGe8UmkqIFpVgmITC8qFE09Kz6FRmW7e7a9CZZ7Ym22H",
  render_errors: [view: OctopusWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Octopus.PubSub,
  live_view: [signing_salt: "v2oIwOvL"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
