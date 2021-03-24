defmodule Octopus.Client.Hubspot do
  defmodule Behaviour do
    @callback store_procurement_data(list(map())) :: list(map())
  end

  @behaviour Behaviour
  use Tesla, only: [:post]

  @procurement_data_email_field "Email"

  plug Tesla.Middleware.BaseUrl, "https://api.hubapi.com/contacts/v1/contact"
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger

  @impl true
  def store_procurement_data(data) do
    case post!("/batch/", body(data),
           query: [hapikey: api_key()],
           opts: [adapter: [recv_timeout: 30_000]]
         ) do
      %Tesla.Env{status: 202} ->
        data

      rsp = %Tesla.Env{status: 400, body: %{"invalidEmails" => [_ | _]}} ->
        data
        |> remove_invalid_emails(rsp.body)
        |> __MODULE__.store_procurement_data()
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

  defp api_key do
    Application.fetch_env!(:octopus, :hubspot)[:api_key]
  end
end
