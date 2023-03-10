defmodule Octopus.Repo.Migrations.AddReadonlyUser do
  use Ecto.Migration

  def up do
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

  def down do
    if Mix.env() == :prod do
      username = System.fetch_env!("DATABASE_READONLY_USERNAME")
      database = System.fetch_env!("DATABASE_NAME")

      execute(
        "ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON TABLES FROM #{username}"
      )

      execute("REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM #{username}")
      execute("REVOKE USAGE ON SCHEMA public FROM #{username}")
      execute("REVOKE CONNECT ON DATABASE #{database} FROM #{username}")
      execute("DROP USER #{username}")
    end
  end
end
