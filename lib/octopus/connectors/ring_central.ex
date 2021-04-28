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
    case RingCentral.get_call_log(latest_record_datetime, @results_per_page, 1) do
      [] ->
        :ok

      nil ->
        :ok

      call_log = [_ | _] ->
        new_latest_record_datetime = persist_page(call_log)
        Process.sleep(timeout_between_requests())
        get_call_log(latest_record_datetime, new_latest_record_datetime)
    end
  end

  defp get_call_log(latest_record_datetime, new_latest_record_datetime, page \\ 2) do
    call_log = RingCentral.get_call_log(latest_record_datetime, @results_per_page, page)

    case(call_log) do
      [] ->
        ConnectorHistory.update_latest_record_datetime(__MODULE__, new_latest_record_datetime)
        :ok

      [_ | _] ->
        persist_page(call_log)
        Process.sleep(timeout_between_requests())
        get_call_log(latest_record_datetime, new_latest_record_datetime, page + 1)
    end
  end

  defp persist_page([]), do: nil
  defp persist_page(nil), do: nil

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
