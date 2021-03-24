defmodule Octopus.Client.DomoAuth do
  defmodule Behaviour do
    @callback get_token() :: String.t()
  end

  @behaviour Behaviour
  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://api.domo.com/oauth"
  plug Tesla.Middleware.BasicAuth, credentials()
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger

  @impl true
  def get_token do
    %Tesla.Env{status: 200, body: %{"access_token" => token}} =
      get!("/token",
        query: [
          grant_type: "client_credentials",
          scope: "data"
        ]
      )

    token
  end

  defp credentials do
    [
      username: Application.fetch_env!(:octopus, :domo)[:username],
      password: Application.fetch_env!(:octopus, :domo)[:password]
    ]
  end
end
