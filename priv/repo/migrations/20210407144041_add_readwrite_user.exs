defmodule Octopus.Repo.Migrations.AddReadwriteUser do
  use Ecto.Migration

  def up do
    if Mix.env() == :prod do
      username = System.fetch_env!("DATABASE_TRANSFORMER_USERNAME")
      password = System.fetch_env!("DATABASE_TRANSFORMER_PASSWORD")
      database = System.fetch_env!("DATABASE_NAME")

      execute("CREATE USER #{username} WITH PASSWORD '#{password}'")
      execute("GRANT CONNECT ON DATABASE #{database} TO #{username}")
      execute("GRANT USAGE ON SCHEMA public TO #{username}")
      execute("GRANT ALL ON ALL TABLES IN SCHEMA public TO #{username}")
      execute("GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO #{username}")
      execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO #{username}")
      execute("GRANT ALL ON DATABASE #{database} TO #{username}")
    end
  end

  def down do
    if Mix.env() == :prod do
      username = System.fetch_env!("DATABASE_TRANSFORMER_USERNAME")
      database = System.fetch_env!("DATABASE_NAME")

      execute("REVOKE ALL ON DATABASE #{database} FROM #{username}")
      execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM #{username}")
      execute("REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM #{username}")
      execute("REVOKE ALL ON ALL TABLES IN SCHEMA public FROM #{username}")
      execute("REVOKE USAGE ON SCHEMA public FROM #{username}")
      execute("REVOKE CONNECT ON DATABASE #{database} FROM #{username}")
      execute("DROP USER #{username}")
    end
  end
end
