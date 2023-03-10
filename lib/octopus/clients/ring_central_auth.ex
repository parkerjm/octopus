defmodule Octopus.Client.RingCentralAuth do
  defmodule Behaviour do
    @callback get_token() :: {String.t(), number()}
  end

  @behaviour Behaviour
  use Tesla

  @impl true
  def get_token do
    %Tesla.Env{status: 200, body: %{"access_token" => token, "expires_in" => expiry}} =
      post!(client(), "/oauth/token", user_credentials())

    {token, expiry}
  end

  defp client do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url()},
      {Tesla.Middleware.BasicAuth, app_credentials()},
      Tesla.Middleware.FormUrlencoded,
      Tesla.Middleware.JSON,
      Tesla.Middleware.Logger
    ]

    Tesla.client(middleware)
  end

  defp base_url do
    Application.fetch_env!(:octopus, :ring_central)[:base_url]
  end

  defp user_credentials do
    %{
      username: Application.fetch_env!(:octopus, :ring_central)[:username],
      password: Application.fetch_env!(:octopus, :ring_central)[:password],
      grant_type: "password"
    }
  end

  defp app_credentials do
    [
      username: Application.fetch_env!(:octopus, :ring_central)[:client_id],
      password: Application.fetch_env!(:octopus, :ring_central)[:secret]
    ]
  end
end
