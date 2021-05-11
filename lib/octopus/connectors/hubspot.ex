defmodule Octopus.Connector.Hubspot do
  use Oban.Worker

  alias Octopus.{ConnectorHistory, Client.Hubspot}

  @contacts_per_page 100
  @email_events_per_page 1000
  @email_events ["SENT", "OPEN", "CLICK", "STATUSCHANGE"]

  def start_link(_args) do
    Task.start_link(__MODULE__, :run, [])
  end

  def email_events do
    @email_events
  end

  @impl Oban.Worker
  def perform(_args) do
    %ConnectorHistory{state: state, latest_record_time_unix: latest_record_time_unix} =
      ConnectorHistory.get_history(__MODULE__)

    tasks = [
      Task.async(fn -> get_contacts(latest_record_time_unix) end),
      Task.async(fn -> get_email_events(state) end)
    ]

    Task.await_many(tasks, :infinity)
  end

  defp get_email_events(nil), do: get_email_events(%{"email_events" => %{}})

  defp get_email_events(%{"email_events" => timestamps} = state) do
    Enum.map(@email_events, fn event_type ->
      latest_event_timestamp = fetch_email_events(event_type, timestamps[event_type])

      __MODULE__
      |> ConnectorHistory.get_history()
      |> (&(Map.get(&1, :state) || state)).()
      |> put_in(["email_events", event_type], latest_event_timestamp)
      |> (&ConnectorHistory.update_state(__MODULE__, &1)).()
    end)
  end

  defp fetch_email_events(event_type, from_timestamp) do
    %{offset: offset, events: email_events} =
      Hubspot.get_email_events(event_type,
        from_timestamp: from_timestamp,
        per_page: @email_events_per_page
      )

    case email_events do
      [] ->
        from_timestamp

      nil ->
        from_timestamp

      email_events = [_ | _] ->
        latest_event_timestamp = persist_events(email_events)
        Process.sleep(timeout_between_requests())
        fetch_email_events(event_type, from_timestamp, latest_event_timestamp, offset)
    end
  end

  defp fetch_email_events(event_type, from_timestamp, latest_event_timestamp, offset) do
    %{offset: offset, events: email_events} =
      Hubspot.get_email_events(event_type,
        from_timestamp: from_timestamp,
        per_page: @email_events_per_page,
        offset: offset
      )

    case(email_events) do
      [] ->
        latest_event_timestamp

      [_ | _] ->
        persist_events(email_events)
        Process.sleep(timeout_between_requests())
        fetch_email_events(event_type, from_timestamp, latest_event_timestamp, offset)
    end
  end

  defp persist_events([]), do: nil
  defp persist_events(nil), do: nil

  defp persist_events(events) when length(events) > 0 do
    events
    |> Octopus.Sink.Warehouse.store("hubspot_email_events")
    |> List.first()
    |> Map.get("created")
  end

  defp get_contacts(latest_record_time_unix) do
    contacts = Hubspot.get_contacts(latest_record_time_unix, @contacts_per_page)

    new_latest_record_time_unix = persist_contacts(contacts)

    if new_latest_record_time_unix,
      do: ConnectorHistory.update_latest_record_time_unix(__MODULE__, new_latest_record_time_unix)

    case(length(contacts)) do
      len when len < @contacts_per_page ->
        :ok

      _ ->
        Process.sleep(timeout_between_requests())
        get_contacts(new_latest_record_time_unix)
    end
  end

  defp persist_contacts([]), do: nil
  defp persist_contacts(nil), do: nil

  defp persist_contacts(contacts) when length(contacts) > 0 do
    {:ok, latest_datetime, _} =
      contacts
      |> Octopus.Sink.Warehouse.store("hubspot_contacts", ["properties"])
      |> List.last()
      |> Map.get("updatedAt")
      |> DateTime.from_iso8601()

    DateTime.to_unix(latest_datetime, :millisecond)
  end

  defp timeout_between_requests() do
    Application.fetch_env!(:octopus, :hubspot)[:timeout_between_requests]
  end
end
