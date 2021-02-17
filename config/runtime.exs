import Config

if config_env() == :prod do
  config :octopus, OctopusWeb.Endpoint,
    # url: [host: "octopus.crownandcaliber.com", port: 80],
    url: [host: "localhost", port: 8080],
    cache_static_manifest: "priv/static/cache_manifest.json",
    http: [
      port: String.to_integer(System.get_env("PORT") || "8080"),
      transport_options: [socket_opts: [:inet6]]
    ],
    server: true,
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

  config :octopus, Octopus.Repo,
    username: System.fetch_env!("DATABASE_USERNAME"),
    password: System.fetch_env!("DATABASE_PASSWORD"),
    database: System.fetch_env!("DATABASE_NAME"),
    hostname: System.fetch_env!("DATABASE_HOST"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :logger, level: :info

  config :octopus, :delighted,
    api_key: System.fetch_env!("DELIGHTED_API_KEY"),
    timeout_between_requests:
      String.to_integer(System.fetch_env!("DELIGHTED_TIMEOUT_BETWEEN_REQUESTS"))
end
