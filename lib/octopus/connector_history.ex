defmodule Octopus.ConnectorHistory do
  use Ecto.Schema
  import Ecto.Changeset
  alias Octopus.Repo

  schema "connector_history" do
    field(:connector, :string)
    field(:latest_record_time_unix, :integer, default: 0)
    field(:latest_record_date, :date)
    field(:latest_record_datetime, :utc_datetime)
    field(:state, :map)

    timestamps()
  end

  @doc false
  def changeset(connector_history, attrs) do
    connector_history
    |> cast(attrs, [
      :connector,
      :latest_record_time_unix,
      :latest_record_date,
      :latest_record_datetime,
      :state
    ])
    |> validate_required([:connector])
    |> validate_length(:connector, min: 2, max: 250)
    |> validate_number(:latest_record_time_unix, greater_than_or_equal_to: 0)
  end

  @spec get_history(module()) :: %__MODULE__{}
  def get_history(connector) do
    Repo.get_by(__MODULE__, connector: to_string(connector)) || %__MODULE__{}
  end

  @spec update_latest_record_time_unix(module(), integer()) :: %__MODULE__{}
  def update_latest_record_time_unix(connector, latest_record_time_unix) do
    upsert_field(connector, :latest_record_time_unix, latest_record_time_unix)
  end

  @spec update_latest_record_date(module(), Date.t()) :: %__MODULE__{}
  def update_latest_record_date(connector, latest_record_date) do
    upsert_field(connector, :latest_record_date, latest_record_date)
  end

  @spec update_latest_record_datetime(module(), DateTime.t()) :: %__MODULE__{}
  def update_latest_record_datetime(connector, latest_record_datetime) do
    upsert_field(connector, :latest_record_datetime, latest_record_datetime)
  end

  def update_state(connector, state) do
    upsert_field(connector, :state, state)
  end

  @spec cc_epoch_date() :: Date.t()
  def cc_epoch_date, do: ~D[2015-01-01]

  @spec cc_epoch_datetime() :: DateTime.t()
  def cc_epoch_datetime, do: ~U[2015-01-01 00:00:00.000000Z]

  defp upsert_field(connector, field, value) do
    connector
    |> get_history()
    |> changeset(%{:connector => to_string(connector), field => value})
    |> Repo.insert!(conflict_target: :connector, on_conflict: {:replace, [field]})
  end
end
