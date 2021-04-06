defmodule Octopus.Connector.RingCentral do
  use Oban.Worker

  alias Octopus.ConnectorHistory
  alias Octopus.Client.RingCentral

  @results_per_page 100

  def start_link(_args) do
    Task.start_link(__MODULE__, :run, [])
  end

  @impl Oban.Worker
  def perform(_args) do
    %ConnectorHistory{latest_record_datetime: latest_record_datetime} =
      ConnectorHistory.get_history(__MODULE__)

    (latest_record_datetime || ConnectorHistory.cc_epoch_datetime())
    |> DateTime.to_iso8601()
    |> get_call_log()
  end

  defp get_call_log(latest_record_datetime) do
    call_log = RingCentral.get_call_log(latest_record_datetime, @results_per_page)

    new_latest_record_datetime = persist_page(call_log)
    ConnectorHistory.update_latest_record_datetime(__MODULE__, new_latest_record_datetime)

    case(length(call_log)) do
      len when len < @results_per_page ->
        :ok

      _ ->
        Process.sleep(timeout_between_requests())
        get_call_log(new_latest_record_datetime)
    end
  end

  defp persist_page(call_log) do
    call_log
    |> Octopus.Sink.Warehouse.store("ring_central_call_log")
    |> List.first()
    |> Map.get("startTime")
  end

  defp timeout_between_requests() do
    Application.fetch_env!(:octopus, :ring_central)[:timeout_between_requests]
  end
end
