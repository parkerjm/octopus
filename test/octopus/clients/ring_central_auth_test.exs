defmodule Octopus.Client.RingCentralAuthTest do
  use Octopus.DataCase
  import Tesla.Mock
  alias Octopus.Client.RingCentralAuth

  describe "#get_token" do
    test "sends POST request to correct request URL" do
      mock(fn
        %{method: :post, url: "https://platform.devtest.ringcentral.com/restapi/oauth/token"} ->
          {200, %{}, %{"access_token" => "token", "expires_in" => 120}}
      end)

      RingCentralAuth.get_token()
    end

    test "includes basic auth header" do
      expected_auth_header = "Basic #{Base.encode64("fake_client_id:fake_secret")}"

      mock(fn
        %{headers: [{"authorization", ^expected_auth_header} | _rest]} ->
          {200, %{}, %{"access_token" => "token", "expires_in" => 120}}
      end)

      RingCentralAuth.get_token()
    end

    test "sends body in form-urlencoded format" do
      mock(fn
        %{headers: [_, {"content-type", "application/x-www-form-urlencoded"}]} ->
          {200, %{}, %{"access_token" => "token", "expires_in" => 120}}
      end)

      RingCentralAuth.get_token()
    end

    test "sends user creds in body" do
      mock(fn
        %{body: "grant_type=password&password=fake_pass&username=fake_user"} ->
          {200, %{}, %{"access_token" => "token", "expires_in" => 120}}
      end)

      RingCentralAuth.get_token()
    end

    test "returns token" do
      expected_token = "token#{Enum.random(0..1000)}"
      mock(fn _ -> {200, %{}, %{"access_token" => expected_token, "expires_in" => 120}} end)

      assert {^expected_token, _} = RingCentralAuth.get_token()
    end

    test "returns token expiry time" do
      expiry_time = Enum.random(0..1000)
      mock(fn _ -> {200, %{}, %{"access_token" => "token", "expires_in" => expiry_time}} end)

      assert {_, ^expiry_time} = RingCentralAuth.get_token()
    end

    test "raises error if no token is returned" do
      mock(fn _ -> raise RuntimeError, "request failed" end)

      assert_raise RuntimeError, ~r/request failed/, fn -> RingCentralAuth.get_token() end
    end
  end
end
