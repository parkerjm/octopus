defmodule Octopus.ConnectorHistory do
  use Ecto.Schema
  import Ecto.Changeset
  alias Octopus.{Repo, Connector}

  schema "connector_history" do
    field(:connector, :string)
    field(:last_update, :integer, default: 0)

    timestamps()
  end

  @doc false
  def changeset(connector_history, attrs) do
    connector_history
    |> cast(attrs, [:connector, :last_update])
    |> validate_required([:connector, :last_update])
    |> validate_length(:connector, min: 2, max: 250)
    |> validate_number(:last_update, greater_than_or_equal_to: 0)
  end

  @spec get_history(module()) :: %__MODULE__{}
  def get_history(connector) do
    Repo.get_by(__MODULE__, connector: to_string(connector)) || %__MODULE__{}
  end

  @spec update_last_run_time(module(), integer()) :: %__MODULE__{}
  def update_last_run_time(connector, last_update) do
    connector
    |> get_history()
    |> changeset(%{connector: to_string(connector), last_update: last_update})
    |> Repo.insert!(conflict_target: :connector, on_conflict: {:replace, [:last_update]})
  end
end
