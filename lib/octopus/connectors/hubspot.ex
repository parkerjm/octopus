defmodule Octopus.Connector.Hubspot do
  use Oban.Worker

  alias Octopus.ConnectorHistory

  @results_per_page 100

  def start_link(_args) do
    Task.start_link(__MODULE__, :run, [])
  end

  @impl Oban.Worker
  def perform(_args) do
    %ConnectorHistory{latest_record_time_unix: latest_record_time_unix} =
      ConnectorHistory.get_history(__MODULE__)

    get_contacts(latest_record_time_unix)
  end

  defp get_contacts(latest_record_time_unix) do
    contacts = Octopus.Client.Hubspot.get_contacts(latest_record_time_unix, @results_per_page)

    new_latest_record_time_unix = persist_page(contacts) || latest_record_time_unix
    ConnectorHistory.update_latest_record_time_unix(__MODULE__, new_latest_record_time_unix)

    case(length(contacts)) do
      len when len < @results_per_page ->
        :ok

      _ ->
        Process.sleep(timeout_between_requests())
        get_contacts(new_latest_record_time_unix)
    end
  end

  defp persist_page([]), do: nil
  defp persist_page(nil), do: nil

  defp persist_page(contacts) when length(contacts) > 0 do
    {:ok, latest_datetime, _} =
      contacts
      |> Octopus.Sink.Warehouse.store("hubspot_contacts", ["properties"])
      |> List.last()
      |> Map.get("updatedAt")
      |> DateTime.from_iso8601()

    DateTime.to_unix(latest_datetime, :millisecond)
  end

  defp timeout_between_requests() do
    Application.fetch_env!(:octopus, :hubspot)[:timeout_between_requests]
  end
end
