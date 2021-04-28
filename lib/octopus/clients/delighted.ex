defmodule Octopus.Client.Delighted do
  defmodule Behaviour do
    @callback get_survey_responses(number(), number()) :: list(map())
  end

  @behaviour Behaviour
  use Tesla, only: [:get]
  require Logger

  @impl true
  def get_survey_responses(updated_since \\ 0, per_page \\ 100) do
    Logger.info(
      "Client.Delighted: Getting survey responses from timestamp #{updated_since} with #{per_page} per page"
    )

    {:ok, %Tesla.Env{body: survey_responses}} =
      get(client(), "/survey_responses.json",
        query: [updated_since: updated_since, per_page: per_page, expand: ["person", "notes"]]
      )

    survey_responses
  end

  defp client do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url()},
      {Tesla.Middleware.Headers, [{"authorization", "Basic #{basic_auth_creds()}"}]},
      Tesla.Middleware.JSON,
      Tesla.Middleware.Logger
    ]

    Tesla.client(middleware)
  end

  defp base_url do
    Application.fetch_env!(:octopus, :delighted)[:base_url]
  end

  defp basic_auth_creds() do
    api_key = Application.fetch_env!(:octopus, :delighted)[:api_key]
    Base.encode64("#{api_key}:")
  end
end
