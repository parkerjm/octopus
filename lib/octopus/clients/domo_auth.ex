defmodule Octopus.Client.DomoAuth do
  defmodule Behaviour do
    @callback get_token() :: String.t()
  end

  @behaviour Behaviour
  use Tesla

  @impl true
  def get_token do
    %Tesla.Env{status: 200, body: %{"access_token" => token}} =
      get!(client(), "/oauth/token",
        query: [
          grant_type: "client_credentials",
          scope: "data"
        ]
      )

    token
  end

  defp client do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url()},
      {Tesla.Middleware.BasicAuth, credentials()},
      Tesla.Middleware.JSON,
      Tesla.Middleware.Logger
    ]

    Tesla.client(middleware)
  end

  defp base_url do
    Application.fetch_env!(:octopus, :domo)[:base_url]
  end

  defp credentials do
    [
      username: Application.fetch_env!(:octopus, :domo)[:username],
      password: Application.fetch_env!(:octopus, :domo)[:password]
    ]
  end
end
