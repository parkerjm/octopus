defmodule Octopus.Client.DomoAuthTest do
  use Octopus.DataCase
  alias Octopus.Client.DomoAuth

  setup do
    bypass = Bypass.open()

    env =
      :octopus
      |> Application.get_env(:domo)
      |> Keyword.put(:base_url, "http://localhost:#{bypass.port}")

    Application.put_env(:octopus, :domo, env)

    {:ok, bypass: bypass}
  end

  describe "#get_token" do
    test "sends GET request to correct request URL", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/oauth/token", fn conn ->
        auth_response(conn)
      end)

      DomoAuth.get_token()
    end

    test "includes basic auth header", %{bypass: bypass} do
      expected_auth_header = "Basic #{Base.encode64("fake_user:fake_pass")}"

      Bypass.expect(bypass, "GET", "/oauth/token", fn conn ->
        assert :proplists.get_value("authorization", conn.req_headers) == expected_auth_header
        auth_response(conn)
      end)

      DomoAuth.get_token()
    end

    test "sends query params", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/oauth/token", fn conn ->
        assert conn.query_params["grant_type"] == "client_credentials"
        assert conn.query_params["scope"] == "data"

        auth_response(conn)
      end)

      DomoAuth.get_token()
    end

    test "returns token", %{bypass: bypass} do
      expected_token = "token#{Enum.random(0..1000)}"

      Bypass.expect(bypass, "GET", "/oauth/token", fn conn ->
        auth_response(conn, expected_token)
      end)

      assert DomoAuth.get_token() == expected_token
    end

    test "raises error if no token is returned", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/oauth/token", fn conn ->
        Plug.Conn.resp(conn, 500, "")
      end)

      assert_raise MatchError, fn -> DomoAuth.get_token() end
    end
  end

  defp auth_response(conn, returned_token \\ "token") do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/json")
    |> Plug.Conn.resp(200, token_response(returned_token))
  end

  defp token_response(returned_token) do
    Jason.encode!(%{"access_token" => returned_token})
  end
end
