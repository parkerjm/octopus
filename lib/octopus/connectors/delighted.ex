defmodule Octopus.Connector.Delighted do
  use Oban.Worker
  require Logger
  alias Octopus.ConnectorHistory

  @results_per_page 100

  def start_link(_args) do
    Task.start_link(__MODULE__, :run, [])
  end

  @impl Oban.Worker
  def perform(_args) do
    %ConnectorHistory{last_update: last_update} = ConnectorHistory.get_history(__MODULE__)
    get_survey_responses(last_update)
  end

  defp get_survey_responses(last_update) do
    survey_responses = delighted_client().get_survey_responses(last_update, @results_per_page)

    new_last_update = persist_page(survey_responses)
    ConnectorHistory.update_last_run_time(__MODULE__, new_last_update)

    Process.sleep(timeout_between_requests())

    case(length(survey_responses)) do
      len when len < @results_per_page -> :ok
      _ -> get_survey_responses(new_last_update)
    end
  end

  defp persist_page(survey_responses) when length(survey_responses) > 0 do
    survey_responses
    |> warehouse().store("delighted_survey_responses")
    |> List.last()
    |> Map.get("updated_at")
  end

  defp timeout_between_requests() do
    Application.fetch_env!(:octopus, :delighted)[:timeout_between_requests]
  end

  defp delighted_client do
    Application.get_env(:octopus, :delighted_client)
  end

  defp warehouse do
    Application.get_env(:octopus, :warehouse)
  end
end
