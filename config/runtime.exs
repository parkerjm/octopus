import Config

if config_env() == :prod do
  config :octopus, OctopusWeb.Endpoint,
    url: [host: System.fetch_env!("HOSTNAME"), port: 80],
    http: [
      port: String.to_integer(System.get_env("PORT") || "8080"),
      transport_options: [socket_opts: [:inet6]]
    ],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

  config :octopus, :dashboard,
    username: System.fetch_env!("DASHBOARD_USERNAME"),
    password: System.fetch_env!("DASHBOARD_PASSWORD")

  config :octopus, Octopus.Repo,
    username: System.fetch_env!("DATABASE_USERNAME"),
    password: System.fetch_env!("DATABASE_PASSWORD"),
    database: System.fetch_env!("DATABASE_NAME"),
    hostname: System.fetch_env!("DATABASE_HOST"),
    pool_size: String.to_integer(System.get_env("DATABASE_POOL_SIZE") || "10"),
    pool_timeout: 60_000,
    timeout: 60_000

  unique_opts = [
    period: :infinity,
    states: [:available, :scheduled, :executing, :retryable]
  ]

  shared_crontab = [
    {"*/15 * * * *", Octopus.Connector.Delighted, max_attempts: 1, unique: unique_opts},
    {"*/15 * * * *", Octopus.Connector.RingCentral, max_attempts: 1, unique: unique_opts}
  ]

  production_crontab = [
    {"*/20 * * * *", Octopus.Connector.Domo, max_attempts: 1, unique: unique_opts},
    {"*/30 * * * *", Octopus.Connector.Hubspot, max_attempts: 1, unique: unique_opts}
  ]

  crontab =
    if System.get_env("APP_ENV") == "production" do
      shared_crontab ++ production_crontab
    else
      shared_crontab
    end

  config :octopus, Oban,
    repo: Octopus.Repo,
    plugins: [
      {Oban.Plugins.Pruner, max_age: 3600},
      {Oban.Plugins.Cron, crontab: crontab}
    ],
    queues: [default: 10]

  config :octopus, :delighted,
    api_key: System.fetch_env!("DELIGHTED_API_KEY"),
    base_url: System.fetch_env!("DELIGHTED_BASE_URL"),
    timeout_between_requests:
      String.to_integer(System.fetch_env!("DELIGHTED_TIMEOUT_BETWEEN_REQUESTS"))

  config :octopus, :hubspot,
    api_key: System.fetch_env!("HUBSPOT_API_KEY"),
    base_url: System.fetch_env!("HUBSPOT_BASE_URL"),
    timeout_between_requests:
      String.to_integer(System.fetch_env!("HUBSPOT_TIMEOUT_BETWEEN_REQUESTS"))

  config :octopus, :domo,
    base_url: System.fetch_env!("DOMO_BASE_URL"),
    username: System.fetch_env!("DOMO_USERNAME"),
    password: System.fetch_env!("DOMO_PASSWORD"),
    procurement_dataset_id: System.fetch_env!("DOMO_PROCUREMENT_DATASET_ID"),
    timeout_between_requests:
      String.to_integer(System.fetch_env!("DOMO_TIMEOUT_BETWEEN_REQUESTS"))

  config :octopus, :ring_central,
    base_url: System.fetch_env!("RING_CENTRAL_BASE_URL"),
    client_id: System.fetch_env!("RING_CENTRAL_CLIENT_ID"),
    secret: System.fetch_env!("RING_CENTRAL_CLIENT_SECRET"),
    username: System.fetch_env!("RING_CENTRAL_USERNAME"),
    password: System.fetch_env!("RING_CENTRAL_PASSWORD"),
    timeout_between_requests:
      String.to_integer(System.fetch_env!("RING_CENTRAL_TIMEOUT_BETWEEN_REQUESTS"))
end
