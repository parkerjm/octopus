defmodule Octopus.Connector.DelightedTest do
  use Octopus.DataCase

  import Mox

  alias Octopus.ConnectorHistory
  alias Octopus.Connector.Delighted
  alias Octopus.Client.DelightedMock
  alias Octopus.Sink.WarehouseMock

  setup :verify_on_exit!

  setup do
    last_update = Enum.random(0..10_000_000)

    %ConnectorHistory{connector: to_string(Delighted), last_update: last_update}
    |> Repo.insert!()

    stub(DelightedMock, :get_survey_responses, fn _, _ ->
      List.duplicate(%{"updated_at" => 12345}, 3)
    end)

    stub(WarehouseMock, :store, fn data, _ -> data end)

    {:ok, last_update: last_update}
  end

  describe "#perform" do
    test "connector pulls surveys from last update time", %{last_update: last_update} do
      expect(DelightedMock, :get_survey_responses, fn ^last_update, _ ->
        [%{"updated_at" => 12345}]
      end)

      Delighted.perform(%{})
    end

    test "fetches pages until fewer than max results are returned" do
      DelightedMock
      |> expect_get_survey_responses(100)
      |> expect_get_survey_responses(100)
      |> expect_get_survey_responses(3)

      Delighted.perform(%{})
    end

    test "stores all pages in the warehouse" do
      DelightedMock
      |> expect_get_survey_responses(100)
      |> expect_get_survey_responses(3)

      expect(WarehouseMock, :store, 2, fn data, _table -> data end)
      Delighted.perform(%{})
    end

    test "last update time is stored in connector history" do
      new_last_update = Enum.random(0..10_000_000)
      expect_get_survey_responses(DelightedMock, 1, new_last_update)

      Delighted.perform(%{})

      assert %ConnectorHistory{last_update: ^new_last_update} =
               ConnectorHistory.get_history(Delighted)
    end
  end

  defp expect_get_survey_responses(mock, result_count, updated_at_time \\ 12345) do
    expect(mock, :get_survey_responses, fn _, _ ->
      List.duplicate(%{"updated_at" => updated_at_time}, result_count)
    end)

    mock
  end
end
