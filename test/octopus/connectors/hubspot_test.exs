defmodule Octopus.Connector.HubspotTest do
  use Octopus.DataCase

  import Mox
  import Rewire

  alias Octopus.ConnectorHistory
  alias Octopus.Connector.Hubspot
  alias Octopus.Client.HubspotMock
  alias Octopus.Sink.WarehouseMock

  rewire(Hubspot, Hubspot: HubspotMock)
  rewire(Hubspot, Warehouse: WarehouseMock)

  setup :verify_on_exit!

  setup do
    latest_record_time_unix =
      DateTime.utc_now()
      |> DateTime.add(Enum.random(0..1000), :second)
      |> DateTime.truncate(:second)
      |> DateTime.to_unix(:millisecond)

    %ConnectorHistory{
      connector: to_string(Hubspot),
      latest_record_time_unix: latest_record_time_unix
    }
    |> Repo.insert!()

    stub(HubspotMock, :get_contacts, fn _, _ ->
      List.duplicate(%{"updatedAt" => 12345}, 3)
    end)

    stub(WarehouseMock, :store, fn data, _, _ -> data end)

    {:ok, latest_record_time_unix: latest_record_time_unix}
  end

  describe "#perform" do
    test "connector pulls surveys from last update time", %{
      latest_record_time_unix: latest_record_time_unix
    } do
      expect(HubspotMock, :get_contacts, fn ^latest_record_time_unix, _ ->
        [%{"updatedAt" => DateTime.to_iso8601(DateTime.utc_now())}]
      end)

      Hubspot.perform(%{})
    end

    test "fetches pages until no results are returned" do
      HubspotMock
      |> expect_get_contacts(100)
      |> expect_get_contacts(10)

      Hubspot.perform(%{})
    end

    test "stores all pages in the warehouse" do
      HubspotMock
      |> expect_get_contacts(100)
      |> expect_get_contacts(10)

      expect(WarehouseMock, :store, 2, fn data, _, _ -> data end)
      Hubspot.perform(%{})
    end

    test "stores pages in correct table" do
      HubspotMock
      |> expect_get_contacts(100)
      |> expect_get_contacts(0)

      expect(WarehouseMock, :store, 1, fn data, "hubspot_contacts", _ -> data end)
      Hubspot.perform(%{})
    end

    test "stores pages using correct prefix exclusion list" do
      HubspotMock
      |> expect_get_contacts(100)
      |> expect_get_contacts(0)

      expect(WarehouseMock, :store, 1, fn data, _, ["properties"] -> data end)
      Hubspot.perform(%{})
    end

    test "latest start time is stored in connector history" do
      latest_start_time =
        DateTime.utc_now()
        |> DateTime.add(Enum.random(0..1000), :second)
        |> DateTime.truncate(:second)

      latest_start_time_unix = DateTime.to_unix(latest_start_time, :millisecond)

      expect_get_contacts(HubspotMock, 100, DateTime.to_iso8601(DateTime.utc_now()))
      expect_get_contacts(HubspotMock, 1, DateTime.to_iso8601(latest_start_time))

      Hubspot.perform(%{})

      assert %ConnectorHistory{latest_record_time_unix: ^latest_start_time_unix} =
               ConnectorHistory.get_history(Hubspot)
    end

    test "uses existing timestamp when no results are returned", %{
      latest_record_time_unix: latest_record_time_unix
    } do
      expect_get_contacts(HubspotMock, 0)

      Hubspot.perform(%{})

      assert %ConnectorHistory{latest_record_time_unix: ^latest_record_time_unix} =
               ConnectorHistory.get_history(Hubspot)
    end
  end

  defp expect_get_contacts(mock, result_count, start_time \\ nil) do
    start_time = start_time || DateTime.to_iso8601(DateTime.utc_now())

    expect(mock, :get_contacts, fn _, _ ->
      List.duplicate(%{"updatedAt" => start_time}, result_count)
    end)

    mock
  end
end
