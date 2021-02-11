defmodule Octopus.Repo.Migrations.AddConnectorHistoryTable do
  use Ecto.Migration

  def change do
    create table("connector_history") do
      add :connector, :string, null: false
      add :last_update, :integer, default: 0

      timestamps()
    end

    create index("connector_history", [:connector], unique: true)
  end
end
