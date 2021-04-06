defmodule Octopus.Client.DomoAuthTest do
  use Octopus.DataCase
  import Tesla.Mock
  alias Octopus.Client.DomoAuth

  describe "#get_token" do
    test "sends GET request to correct request URL" do
      mock(fn
        %{method: :get, url: "https://api.domo.com/oauth/token"} ->
          {200, %{}, %{"access_token" => "token"}}
      end)

      DomoAuth.get_token()
    end

    test "includes basic auth header" do
      expected_auth_header = "Basic #{Base.encode64("fake_user:fake_pass")}"

      mock(fn
        %{headers: [{"authorization", ^expected_auth_header} | _rest]} ->
          {200, %{}, %{"access_token" => "token"}}
      end)

      DomoAuth.get_token()
    end

    test "sends query params" do
      mock(fn
        %{query: [grant_type: "client_credentials", scope: "data"]} ->
          {200, %{}, %{"access_token" => "token"}}
      end)

      DomoAuth.get_token()
    end

    test "returns token" do
      expected_token = "token#{Enum.random(0..1000)}"
      mock(fn _ -> {200, %{}, %{"access_token" => expected_token}} end)

      assert DomoAuth.get_token() == expected_token
    end

    test "raises error if no token is returned" do
      mock(fn _ -> raise RuntimeError, "request failed" end)

      assert_raise RuntimeError, ~r/request failed/, fn -> DomoAuth.get_token() end
    end
  end
end
