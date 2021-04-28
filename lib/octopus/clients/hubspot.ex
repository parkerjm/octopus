defmodule Octopus.Client.Hubspot do
  defmodule Behaviour do
    @callback store_procurement_data(list(map())) :: list(map())
    @callback get_contacts(number(), number()) :: list(map())
  end

  @behaviour Behaviour
  use Tesla, only: [:post, :get]
  require Logger

  @procurement_data_email_field "Email"
  @contact_update_timestamp_field "lastmodifieddate"

  @impl true
  def get_contacts(from_date_unix \\ 0, per_page \\ 100) do
    Logger.info(
      "Client.Hubspot: Getting contact records from timestamp #{from_date_unix} with #{per_page} per page"
    )

    {:ok, %Tesla.Env{status: 200, body: %{"results" => contacts}}} =
      post(
        client(),
        "crm/v3/objects/contacts/search",
        %{
          filterGroups: [
            %{
              filters: [
                %{
                  value: from_date_unix,
                  propertyName: @contact_update_timestamp_field,
                  operator: "GT"
                }
              ]
            }
          ],
          properties: get_contact_properties(),
          sorts: [@contact_update_timestamp_field],
          limit: per_page
        },
        query: [hapikey: api_key()],
        opts: [adapter: [recv_timeout: 30_000]]
      )

    contacts
  end

  @impl true
  def store_procurement_data(data) do
    case post!(
           client(),
           "/contacts/v1/contact/batch/",
           body(data),
           query: [hapikey: api_key()],
           opts: [adapter: [recv_timeout: 60_000]]
         ) do
      %Tesla.Env{status: 202} ->
        data

      rsp = %Tesla.Env{status: 400, body: %{"invalidEmails" => [_ | _]}} ->
        data
        |> remove_invalid_emails(rsp.body)
        |> __MODULE__.store_procurement_data()
    end
  end

  defp client do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url()},
      Tesla.Middleware.JSON,
      Tesla.Middleware.Logger
    ]

    Tesla.client(middleware)
  end

  defp get_contact_properties do
    case Cachex.get(:cache, :hubspot_contact_properties) do
      {:ok, [_ | _] = properties} ->
        properties

      {:ok, nil} ->
        {:ok, %Tesla.Env{body: props}} =
          get(client(), "/properties/v1/contacts/properties", query: [hapikey: api_key()])

        properties = Enum.map(props, &Map.get(&1, "name"))
        Cachex.put(:cache, :hubspot_contact_properties, properties, ttl: :timer.minutes(30))
        properties
    end
  end

  defp remove_invalid_emails(data, rsp_body) do
    rsp_body["failureMessages"]
    |> Enum.reverse()
    |> Enum.reduce(data, fn failure, acc ->
      if failure["propertyValidationResult"]["error"] == "INVALID_EMAIL" do
        List.delete_at(acc, failure["index"])
      end
    end)
  end

  defp body(data) do
    Enum.map(data, &params_to_contact/1)
  end

  defp params_to_contact(params) do
    %{
      email: params[@procurement_data_email_field],
      properties: Enum.map(params, fn {key, val} -> map_property(key, val) end)
    }
  end

  defp map_property(key, ""), do: %{property: key, value: ""}
  defp map_property(key, nil), do: %{property: key, value: nil}

  defp map_property(key, val) do
    val =
      if String.match?(key, ~r/date/i) do
        val
        |> Date.from_iso8601!()
        |> DateTime.new!(~T[00:00:00.000], "Etc/UTC")
        |> DateTime.to_unix(:millisecond)
      else
        val
      end

    %{property: key, value: val}
  end

  defp base_url do
    Application.fetch_env!(:octopus, :hubspot)[:base_url]
  end

  defp api_key do
    Application.fetch_env!(:octopus, :hubspot)[:api_key]
  end
end
