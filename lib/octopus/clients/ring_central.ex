defmodule Octopus.Client.RingCentral do
  defmodule Behaviour do
    @callback get_call_log(number(), number()) :: list(map())
  end

  @behaviour Behaviour
  use Tesla, only: [:get]

  @impl true
  def get_call_log(date_from \\ "2017-01-01T00:00:00.000000Z", per_page \\ 100) do
    %Tesla.Env{status: 200, body: %{"records" => call_log}} =
      get!(client(), "v1.0/account/~/call-log", query: [dateFrom: date_from, perPage: per_page])

    call_log
  end

  defp client do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url()},
      {Tesla.Middleware.Headers, [{"authorization", "Bearer #{token()}"}]},
      Tesla.Middleware.JSON,
      Tesla.Middleware.Logger
    ]

    Tesla.client(middleware)
  end

  # TODO replace token caching with token refreshing middleware
  defp token do
    :token_cache
    |> :ets.whereis()
    |> :ets.lookup(:rc_auth_token)
    |> Keyword.get(:rc_auth_token)
    |> case do
      {token, expiry} -> refresh_token(token, expiry)
      _ -> fetch_token()
    end
  end

  defp refresh_token(token, expiry) do
    case DateTime.compare(DateTime.utc_now(), expiry) do
      :gt -> fetch_token()
      :eq -> fetch_token()
      :lt -> token
    end
  end

  defp fetch_token do
    {token, expiry_seconds} = Octopus.Client.RingCentralAuth.get_token()
    expiry = DateTime.add(DateTime.utc_now(), expiry_seconds, :second)

    :token_cache
    |> :ets.whereis()
    |> :ets.insert({:rc_auth_token, {token, expiry}})

    token
  end

  defp base_url do
    Application.fetch_env!(:octopus, :ring_central)[:base_url]
  end
end
