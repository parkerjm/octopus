import Config

if config_env() == :prod do
  config :octopus, OctopusWeb.Endpoint,
    url: [host: System.fetch_env!("HOSTNAME"), port: 80],
    http: [
      port: String.to_integer(System.get_env("PORT") || "8080"),
      transport_options: [socket_opts: [:inet6]]
    ],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

  config :octopus, Octopus.Repo,
    username: System.fetch_env!("DATABASE_USERNAME"),
    password: System.fetch_env!("DATABASE_PASSWORD"),
    database: System.fetch_env!("DATABASE_NAME"),
    hostname: System.fetch_env!("DATABASE_HOST"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :octopus, :delighted, api_key: System.fetch_env!("DELIGHTED_API_KEY")
end
