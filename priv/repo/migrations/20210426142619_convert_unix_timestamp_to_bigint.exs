defmodule Octopus.Repo.Migrations.ConvertUnixTimestampToBigint do
  use Ecto.Migration

  def change do
    alter table(:connector_history) do
      modify :latest_record_time_unix, :bigint
    end
  end
end
