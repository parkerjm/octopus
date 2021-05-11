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
    stub(WarehouseMock, :store, fn data, _, _ -> data end)
    stub(WarehouseMock, :store, fn data, _ -> data end)
    stub(HubspotMock, :get_contacts, fn _, _ -> [] end)
    stub(HubspotMock, :get_email_events, fn _, _ -> %{offset: nil, events: []} end)
    :ok
  end

  describe "#perform -- email events" do
    setup do
      state =
        DateTime.utc_now()
        |> DateTime.add(Enum.random(0..1000), :second)
        |> DateTime.truncate(:second)
        |> DateTime.to_unix(:millisecond)
        |> (&%{
              "email_events" => %{
                "SENT" => &1,
                "OPEN" => &1 + 1,
                "CLICK" => &1 + 2,
                "STATUSCHANGE" => &1 + 3
              }
            }).()

      Repo.insert!(%ConnectorHistory{
        connector: to_string(Hubspot),
        state: state
      })

      {:ok, event_timestamps: state["email_events"]}
    end

    test "connector pulls surveys from last update time", %{
      event_timestamps: event_timestamps
    } do
      Enum.each(Hubspot.email_events(), fn event ->
        expect(HubspotMock, :get_email_events, fn ^event, opts ->
          assert opts[:from_timestamp] == event_timestamps[event]
          []
          %{offset: nil, events: []}
        end)
      end)

      Hubspot.perform(%{})
    end

    test "fetches pages until no results are returned" do
      Enum.each(Hubspot.email_events(), fn event ->
        HubspotMock
        |> expect_get_email_events(event, 10)
        |> expect_get_email_events(event, 5)
        |> expect_get_email_events(event, 0)
      end)

      Hubspot.perform(%{})
    end

    test "stores all pages in correct table" do
      Enum.each(Hubspot.email_events(), fn event ->
        HubspotMock
        |> expect_get_email_events(event, 10)
        |> expect_get_email_events(event, 0)
      end)

      expect(WarehouseMock, :store, length(Hubspot.email_events()), fn data,
                                                                       "hubspot_email_events" ->
        data
      end)

      Hubspot.perform(%{})
    end

    test "latest event created timestamp is stored in connector history state" do
      latest_unix_timestamp =
        DateTime.utc_now()
        |> DateTime.add(Enum.random(0..1000), :second)
        |> DateTime.to_unix(:millisecond)

      Enum.each(Hubspot.email_events(), fn event ->
        HubspotMock
        |> expect_get_email_events(event, 1, latest_unix_timestamp)
        |> expect_get_email_events(event, 0)
      end)

      Hubspot.perform(%{})

      %ConnectorHistory{state: %{"email_events" => new_event_timestamps}} =
        ConnectorHistory.get_history(Hubspot)

      Enum.each(Hubspot.email_events(), fn event ->
        assert new_event_timestamps[event] == latest_unix_timestamp
      end)
    end

    test "uses existing timestamp when no results are returned", %{
      event_timestamps: event_timestamps
    } do
      Enum.each(Hubspot.email_events(), fn event ->
        expect_get_email_events(HubspotMock, event, 0)
      end)

      Hubspot.perform(%{})

      assert %ConnectorHistory{state: %{"email_events" => ^event_timestamps}} =
               ConnectorHistory.get_history(Hubspot)
    end
  end

  describe "#perform -- contacts" do
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

      {:ok, latest_record_time_unix: latest_record_time_unix}
    end

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

  defp expect_get_email_events(mock, event_type, result_count, start_time \\ nil) do
    start_time = start_time || DateTime.to_unix(DateTime.utc_now())

    # call is performed for each event type
    expect(mock, :get_email_events, fn ^event_type, _opts ->
      %{
        offset: "offset#{Enum.random(0..1000)}",
        events: List.duplicate(%{"type" => event_type, "created" => start_time}, result_count)
      }
    end)

    mock
  end
end
