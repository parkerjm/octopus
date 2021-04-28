defmodule Octopus.Client.RingCentralAuthTest do
  use Octopus.DataCase
  alias Octopus.Client.RingCentralAuth

  setup do
    bypass = Bypass.open()

    :octopus
    |> Application.get_env(:ring_central)
    |> Keyword.put(:base_url, "http://localhost:#{bypass.port}")
    |> (&Application.put_env(:octopus, :ring_central, &1)).()

    {:ok, bypass: bypass}
  end

  describe "#get_token" do
    test "sends POST request to correct request URL", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/oauth/token", fn conn ->
        auth_response(conn)
      end)

      RingCentralAuth.get_token()
    end

    test "includes basic auth header", %{bypass: bypass} do
      expected_auth_header = "Basic #{Base.encode64("fake_client_id:fake_secret")}"

      Bypass.expect(bypass, "POST", "/oauth/token", fn conn ->
        assert :proplists.get_value("authorization", conn.req_headers) == expected_auth_header
        auth_response(conn)
      end)

      RingCentralAuth.get_token()
    end

    test "sends body in form-urlencoded format", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/oauth/token", fn conn ->
        assert :proplists.get_value("content-type", conn.req_headers) ==
                 "application/x-www-form-urlencoded"

        auth_response(conn)
      end)

      RingCentralAuth.get_token()
    end

    test "sends user creds in body", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/oauth/token", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == "grant_type=password&password=fake_pass&username=fake_user"

        auth_response(conn)
      end)

      RingCentralAuth.get_token()
    end

    test "returns token", %{bypass: bypass} do
      expected_token = "token#{Enum.random(0..1000)}"

      Bypass.expect(bypass, "POST", "/oauth/token", fn conn ->
        auth_response(conn, expected_token)
      end)

      assert {^expected_token, _} = RingCentralAuth.get_token()
    end

    test "returns token expiry time", %{bypass: bypass} do
      expiry_time = Enum.random(0..1000)

      Bypass.expect(bypass, "POST", "/oauth/token", fn conn ->
        auth_response(conn, "token", expiry_time)
      end)

      assert {_, ^expiry_time} = RingCentralAuth.get_token()
    end

    test "raises error if no token is returned", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/oauth/token", fn conn ->
        Plug.Conn.resp(conn, 500, "")
      end)

      assert_raise MatchError, fn -> RingCentralAuth.get_token() end
    end
  end

  defp auth_response(conn, returned_token \\ "token", returned_expiry_time \\ 120) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/json")
    |> Plug.Conn.resp(200, token_response(returned_token, returned_expiry_time))
  end

  defp token_response(returned_token, returned_expiry_time) do
    Jason.encode!(%{"access_token" => returned_token, "expires_in" => returned_expiry_time})
  end
end
