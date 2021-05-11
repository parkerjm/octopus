defmodule Octopus.Repo.Migrations.AddStateJsonToConnectoryHistory do
  use Ecto.Migration

  def change do
    alter table(:connector_history) do
      add :state, :json
    end
  end
end
