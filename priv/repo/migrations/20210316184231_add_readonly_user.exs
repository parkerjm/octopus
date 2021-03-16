defmodule Octopus.Repo.Migrations.AddReadonlyUser do
  use Ecto.Migration

  def change do
    if Mix.env() == :prod do
      username = System.fetch_env!("DATABASE_READONLY_USERNAME")
      password = System.fetch_env!("DATABASE_READONLY_PASSWORD")
      database = System.fetch_env!("DATABASE_NAME")

      execute("CREATE USER #{username} WITH PASSWORD '#{password}'")
      execute("GRANT CONNECT ON DATABASE #{database} TO #{username}")
      execute("GRANT USAGE ON SCHEMA public TO #{username}")
      execute("GRANT SELECT ON ALL TABLES IN SCHEMA public TO #{username}")
      execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO #{username}")
    end
  end
end
