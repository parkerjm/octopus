defmodule Octopus.Repo.Migrations.EnablePglinkAndFdwExtensions do
  use Ecto.Migration

  def change do
    execute(
      "CREATE EXTENSION IF NOT EXISTS \"dblink\"",
      "DROP EXTENSION IF EXISTS \"dblink\""
    )

    execute(
      "CREATE EXTENSION IF NOT EXISTS \"postgres_fdw\"",
      "DROP EXTENSION IF EXISTS \"postgres_fdw\""
    )
  end
end
