defmodule Octopus.Connector.DelightedTest do
  use Octopus.DataCase

  import Mox
  import Rewire

  alias Octopus.ConnectorHistory
  alias Octopus.Connector.Delighted
  alias Octopus.Client.DelightedMock
  alias Octopus.Sink.WarehouseMock

  rewire(Delighted, Delighted: DelightedMock)
  rewire(Delighted, Warehouse: WarehouseMock)

  setup :verify_on_exit!

  setup do
    latest_record_time_unix = Enum.random(0..10_000_000)

    %ConnectorHistory{
      connector: to_string(Delighted),
      latest_record_time_unix: latest_record_time_unix
    }
    |> Repo.insert!()

    stub(DelightedMock, :get_survey_responses, fn _, _ ->
      List.duplicate(%{"updated_at" => 12345}, 3)
    end)

    stub(WarehouseMock, :store, fn data, _ -> data end)

    {:ok, latest_record_time_unix: latest_record_time_unix}
  end

  describe "#perform" do
    test "connector pulls surveys from last update time", %{
      latest_record_time_unix: latest_record_time_unix
    } do
      expect(DelightedMock, :get_survey_responses, fn ^latest_record_time_unix, _ ->
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
      new_latest_record_time_unix = Enum.random(0..10_000_000)
      expect_get_survey_responses(DelightedMock, 1, new_latest_record_time_unix)

      Delighted.perform(%{})

      assert %ConnectorHistory{latest_record_time_unix: ^new_latest_record_time_unix} =
               ConnectorHistory.get_history(Delighted)
    end

    test "uses existing timestamp when no results are returned", %{
      latest_record_time_unix: latest_record_time_unix
    } do
      expect_get_survey_responses(DelightedMock, 0)

      Delighted.perform(%{})

      assert %ConnectorHistory{latest_record_time_unix: ^latest_record_time_unix} =
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
