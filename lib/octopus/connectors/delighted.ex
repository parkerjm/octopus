defmodule Octopus.Connector.Delighted do
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

    get_survey_responses(latest_record_time_unix)
  end

  defp get_survey_responses(latest_record_time_unix) do
    survey_responses =
      Octopus.Client.Delighted.get_survey_responses(latest_record_time_unix, @results_per_page)

    new_latest_record_time_unix = persist_page(survey_responses)
    ConnectorHistory.update_latest_record_time_unix(__MODULE__, new_latest_record_time_unix)

    Process.sleep(timeout_between_requests())

    case(length(survey_responses)) do
      len when len < @results_per_page -> :ok
      _ -> get_survey_responses(new_latest_record_time_unix)
    end
  end

  defp persist_page(survey_responses) when length(survey_responses) > 0 do
    survey_responses
    |> Octopus.Sink.Warehouse.store("delighted_survey_responses")
    |> List.last()
    |> Map.get("updated_at")
  end

  defp timeout_between_requests() do
    Application.fetch_env!(:octopus, :delighted)[:timeout_between_requests]
  end
end
