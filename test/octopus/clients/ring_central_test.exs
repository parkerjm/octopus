defmodule Octopus.Client.RingCentralTest do
  use Octopus.DataCase
  import Mox
  import Rewire
  alias Octopus.Client.{RingCentral, RingCentralAuthMock}

  rewire(RingCentral, RingCentralAuth: RingCentralAuthMock)

  setup :verify_on_exit!

  setup do
    bypass = Bypass.open()

    :octopus
    |> Application.get_env(:ring_central)
    |> Keyword.put(:base_url, "http://localhost:#{bypass.port}")
    |> (&Application.put_env(:octopus, :ring_central, &1)).()

    stub(RingCentralAuthMock, :get_token, fn -> {"token", 120} end)

    on_exit(fn ->
      :token_cache
      |> :ets.whereis()
      |> :ets.delete_all_objects()
    end)

    {:ok, bypass: bypass}
  end

  describe "#get_call_log" do
    test "sends GET request to correct request URL", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/v1.0/account/~/call-log", fn conn ->
        call_log_response(conn)
      end)

      RingCentral.get_call_log()
    end

    test "sends bearer token in request headers", %{bypass: bypass} do
      expected_token = "token#{Enum.random(0..1000)}"
      expected_auth_header = "Bearer #{expected_token}"
      stub(RingCentralAuthMock, :get_token, fn -> {expected_token, 120} end)

      Bypass.expect(bypass, "GET", "/v1.0/account/~/call-log", fn conn ->
        assert :proplists.get_value("authorization", conn.req_headers) == expected_auth_header
        call_log_response(conn)
      end)

      RingCentral.get_call_log()
    end

    test "does not fetch new token if an unexpired one is cached", %{bypass: bypass} do
      stub(RingCentralAuthMock, :get_token, fn ->
        raise RuntimeError, "token fetched when it shouldn't be"
      end)

      :token_cache
      |> :ets.whereis()
      |> :ets.insert({:rc_auth_token, {"token", ~U[3000-01-01 00:00:00.000000Z]}})

      Bypass.expect(bypass, "GET", "/v1.0/account/~/call-log", fn conn ->
        call_log_response(conn)
      end)

      RingCentral.get_call_log()
    end

    test "fetches new token if expired token is cached", %{bypass: bypass} do
      :token_cache
      |> :ets.whereis()
      |> :ets.insert({:rc_auth_token, {"token", ~U[2000-01-01 00:00:00.000000Z]}})

      expect(RingCentralAuthMock, :get_token, fn -> {"token", 10} end)

      Bypass.stub(bypass, "GET", "/v1.0/account/~/call-log", fn conn ->
        call_log_response(conn)
      end)

      RingCentral.get_call_log()
    end

    test "fetches new token if no token is cached", %{bypass: bypass} do
      :token_cache
      |> :ets.whereis()
      |> :ets.delete_all_objects()

      expect(RingCentralAuthMock, :get_token, fn -> {"token", 10} end)

      Bypass.stub(bypass, "GET", "/v1.0/account/~/call-log", fn conn ->
        call_log_response(conn)
      end)

      RingCentral.get_call_log()
    end

    test "defaults query params to correct values", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/v1.0/account/~/call-log", fn conn ->
        assert conn.query_params["dateFrom"] == "2017-01-01T00:00:00.000000Z"
        assert conn.query_params["perPage"] == "100"
        assert conn.query_params["page"] == "1"
        assert conn.query_params["view"] == "Detailed"

        call_log_response(conn)
      end)

      RingCentral.get_call_log()
    end

    test "overrides query params if values are provided", %{bypass: bypass} do
      date_from = Enum.random(0..1000)
      per_page = Enum.random(0..100)
      page = Enum.random(0..100)

      Bypass.expect(bypass, "GET", "/v1.0/account/~/call-log", fn conn ->
        assert conn.query_params["dateFrom"] == to_string(date_from)
        assert conn.query_params["perPage"] == to_string(per_page)
        assert conn.query_params["page"] == to_string(page)
        assert conn.query_params["view"] == "Detailed"

        call_log_response(conn)
      end)

      RingCentral.get_call_log(date_from, per_page, page)
    end

    test "returns list of log entries", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/v1.0/account/~/call-log", fn conn ->
        call_log_response(conn)
      end)

      assert [_ | _] = call_log = RingCentral.get_call_log()
      assert length(call_log) == 10
      assert %{} = List.first(call_log)
    end
  end

  defp call_log_response(conn) do
    calls = List.duplicate(%{to: "my dude"}, 10)
    records = %{records: calls} |> Jason.encode!()

    conn
    |> Plug.Conn.put_resp_header("content-type", "application/json")
    |> Plug.Conn.resp(200, records)
  end
end
