defmodule Octopus.Connector.Domo do
  use Oban.Worker

  alias Octopus.ConnectorHistory
  alias Octopus.Client.{Domo, Hubspot}

  @results_per_page 1000
  @procurement_timestamp_field "Procurement_Lead_Submission_Date_1"

  def start_link(_args) do
    Task.start_link(__MODULE__, :run, [])
  end

  @impl Oban.Worker
  def perform(_args) do
    %ConnectorHistory{latest_record_date: latest_record_date} =
      ConnectorHistory.get_history(__MODULE__)

    (latest_record_date || ConnectorHistory.cc_epoch_date())
    |> Date.to_string()
    |> get_procurement_data()
  end

  defp get_procurement_data(latest_record_date) do
    procurement_data = Domo.get_procurement_data(latest_record_date, @results_per_page)

    new_latest_record_date = persist_page(procurement_data)
    ConnectorHistory.update_latest_record_date(__MODULE__, new_latest_record_date)

    case(length(procurement_data)) do
      len when len < @results_per_page ->
        :ok

      _ ->
        Process.sleep(timeout_between_requests())
        get_procurement_data(new_latest_record_date)
    end
  end

  defp persist_page(procurement_data) do
    procurement_data
    |> Hubspot.store_procurement_data()
    |> List.last()
    |> Map.get(@procurement_timestamp_field)
  end

  defp timeout_between_requests() do
    Application.fetch_env!(:octopus, :domo)[:timeout_between_requests]
  end
end
