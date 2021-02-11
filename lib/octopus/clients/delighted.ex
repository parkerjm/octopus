defmodule Octopus.Client.Delighted do
  @behaviour Octopus.Client.DelightedClient
  use Tesla

  plug(Tesla.Middleware.BaseUrl, "https://api.delighted.com/v1/")
  plug(Tesla.Middleware.Headers, [{"authorization", "Basic #{basic_auth_creds()}"}])
  plug(Tesla.Middleware.JSON)

  @impl true
  def get_survey_responses(updated_since \\ 0, per_page \\ 100) do
    {:ok, %Tesla.Env{body: survey_responses}} =
      get("/survey_responses.json",
        query: [updated_since: updated_since, per_page: per_page]
      )

    survey_responses
  end

  defp basic_auth_creds() do
    api_key = Application.fetch_env!(:octopus, :delighted)[:api_key]
    Base.encode64("#{api_key}:")
  end
end
