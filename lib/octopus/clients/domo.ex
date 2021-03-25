defmodule Octopus.Client.Domo do
  defmodule Behaviour do
    @callback get_procurement_data(String.t(), number()) :: list(map())
  end

  @behaviour Behaviour
  use Tesla, only: [:post]

  @impl true
  def get_procurement_data(procured_since, per_page) do
    %Tesla.Env{status: 200, body: procurement_data} =
      post!(client(), procurement_dataset_id(), query(procured_since, per_page))

    Enum.map(procurement_data["rows"], fn row ->
      procurement_data["columns"] |> Enum.zip(row) |> Map.new()
    end)
  end

  defp client do
    middleware = [
      {Tesla.Middleware.BaseUrl, "https://api.domo.com/v1/datasets/query/execute/"},
      {Tesla.Middleware.Headers, [{"authorization", "Bearer #{token()}"}]},
      Tesla.Middleware.JSON,
      Tesla.Middleware.Logger
    ]

    Tesla.client(middleware)
  end

  defp token do
    Octopus.Client.DomoAuth.get_token()
  end

  defp query(procured_since, per_page) do
    %{
      "sql" => """
      SELECT * FROM table
       WHERE Procurement_Lead_Submission_Date_1 >= '#{procured_since}'
       ORDER BY Procurement_Lead_Submission_Date_1 ASC
       LIMIT #{per_page}
      """
    }
  end

  defp procurement_dataset_id() do
    Application.fetch_env!(:octopus, :domo)[:procurement_dataset_id]
  end
end
