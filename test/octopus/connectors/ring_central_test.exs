defmodule Octopus.Connector.RingCentralTest do
  use Octopus.DataCase

  import Mox
  import Rewire

  alias Octopus.ConnectorHistory
  alias Octopus.Connector.RingCentral
  alias Octopus.Client.RingCentralMock
  alias Octopus.Sink.WarehouseMock

  rewire(RingCentral, RingCentral: RingCentralMock)
  rewire(RingCentral, Warehouse: WarehouseMock)

  setup :verify_on_exit!

  setup do
    latest_record_datetime =
      DateTime.utc_now()
      |> DateTime.add(Enum.random(0..1000), :second)
      |> DateTime.truncate(:second)

    %ConnectorHistory{
      connector: to_string(RingCentral),
      latest_record_datetime: latest_record_datetime
    }
    |> Repo.insert!()

    stub(RingCentralMock, :get_call_log, fn _, _, _ ->
      List.duplicate(%{"updated_at" => 12345}, 3)
    end)

    stub(WarehouseMock, :store, fn data, _ -> data end)

    {:ok, latest_record_datetime: DateTime.to_iso8601(latest_record_datetime)}
  end

  describe "#perform" do
    test "connector pulls surveys from last update time", %{
      latest_record_datetime: latest_record_datetime
    } do
      expect(RingCentralMock, :get_call_log, fn ^latest_record_datetime, _, _ ->
        [%{"startTime" => DateTime.to_iso8601(DateTime.utc_now())}]
      end)

      expect(RingCentralMock, :get_call_log, fn ^latest_record_datetime, _, _ ->
        []
      end)

      RingCentral.perform(%{})
    end

    test "fetches pages until no results are returned" do
      RingCentralMock
      |> expect_get_call_log(100)
      |> expect_get_call_log(10)
      |> expect_get_call_log(0)

      RingCentral.perform(%{})
    end

    test "stores all pages in the warehouse" do
      RingCentralMock
      |> expect_get_call_log(100)
      |> expect_get_call_log(10)
      |> expect_get_call_log(0)

      expect(WarehouseMock, :store, 2, fn data, _table -> data end)
      RingCentral.perform(%{})
    end

    test "stores pages in correct table" do
      RingCentralMock
      |> expect_get_call_log(100)
      |> expect_get_call_log(0)

      expect(WarehouseMock, :store, 1, fn data, "ring_central_call_log" -> data end)
      RingCentral.perform(%{})
    end

    test "latest start time is stored in connector history" do
      latest_start_time =
        DateTime.utc_now()
        |> DateTime.add(Enum.random(0..1000), :second)
        |> DateTime.truncate(:second)

      expect_get_call_log(RingCentralMock, 1, latest_start_time)
      expect_get_call_log(RingCentralMock, 0, DateTime.utc_now())

      RingCentral.perform(%{})

      assert %ConnectorHistory{latest_record_datetime: ^latest_start_time} =
               ConnectorHistory.get_history(RingCentral)
    end

    test "uses existing timestamp when no results are returned", %{
      latest_record_datetime: latest_record_datetime
    } do
      expect_get_call_log(RingCentralMock, 0)

      RingCentral.perform(%{})

      %ConnectorHistory{latest_record_datetime: actual_latest_record_datetime} =
        ConnectorHistory.get_history(RingCentral)

      assert DateTime.to_iso8601(actual_latest_record_datetime) == latest_record_datetime
    end
  end

  defp expect_get_call_log(mock, result_count, start_time \\ nil) do
    start_time = start_time || DateTime.to_iso8601(DateTime.utc_now())

    expect(mock, :get_call_log, fn _, _, _ ->
      List.duplicate(%{"startTime" => start_time}, result_count)
    end)

    mock
  end
end
