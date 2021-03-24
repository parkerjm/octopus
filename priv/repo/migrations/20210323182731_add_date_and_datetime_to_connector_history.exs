defmodule Octopus.Repo.Migrations.AddDateAndDatetimeToConnectorHistory do
  use Ecto.Migration

  def change do
    alter table(:connector_history) do
      add :latest_record_date, :date
      add :latest_record_datetime, :utc_datetime
    end

    rename table(:connector_history), :last_update, to: :latest_record_time_unix
  end
end
