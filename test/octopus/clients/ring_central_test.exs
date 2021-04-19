defmodule Octopus.Client.RingCentralTest do
  use Octopus.DataCase
  import Mox
  import Rewire
  import Tesla.Mock
  alias Octopus.Client.{RingCentral, RingCentralAuthMock}

  rewire(RingCentral, RingCentralAuth: RingCentralAuthMock)

  setup :verify_on_exit!

  setup do
    stub(RingCentralAuthMock, :get_token, fn -> {"token", 120} end)

    on_exit(fn ->
      :token_cache
      |> :ets.whereis()
      |> :ets.delete_all_objects()
    end)

    :ok
  end

  describe "#get_call_log" do
    test "sends GET request to correct request URL" do
      mock(fn
        %{
          method: :get,
          url: "https://platform.devtest.ringcentral.com/restapi/v1.0/account/~/call-log"
        } ->
          %Tesla.Env{status: 200, body: %{"records" => []}}
      end)

      assert RingCentral.get_call_log() == []
    end

    test "sends bearer token in request headers" do
      expected_token = "token#{Enum.random(0..1000)}"
      expected_auth_header = "Bearer #{expected_token}"

      stub(RingCentralAuthMock, :get_token, fn -> {expected_token, 120} end)

      mock(fn
        %{headers: [{"authorization", ^expected_auth_header}]} ->
          %Tesla.Env{status: 200, body: %{"records" => "authorized"}}
      end)

      assert RingCentral.get_call_log() == "authorized"
    end

    test "does not fetch new token if an unexpired one is cached" do
      stub(RingCentralAuthMock, :get_token, fn ->
        raise RuntimeError, "token fetched when it shouldn't be"
      end)

      :token_cache
      |> :ets.whereis()
      |> :ets.insert({:rc_auth_token, {"token", ~U[3000-01-01 00:00:00.000000Z]}})

      mock(fn
        _ -> %Tesla.Env{status: 200, body: %{"records" => []}}
      end)

      RingCentral.get_call_log()
    end

    test "fetches new token if expired token is cached" do
      :token_cache
      |> :ets.whereis()
      |> :ets.insert({:rc_auth_token, {"token", ~U[2000-01-01 00:00:00.000000Z]}})

      stub(RingCentralAuthMock, :get_token, fn -> {"token", 10} end)

      mock(fn
        _ -> %Tesla.Env{status: 200, body: %{"records" => []}}
      end)

      RingCentral.get_call_log()
    end

    test "fetches new token if no token is cached" do
      :token_cache
      |> :ets.whereis()
      |> :ets.delete_all_objects()

      stub(RingCentralAuthMock, :get_token, fn -> {"token", 10} end)

      mock(fn
        _ -> %Tesla.Env{status: 200, body: %{"records" => []}}
      end)

      RingCentral.get_call_log()
    end

    test "defaults query params to correct values" do
      mock(fn
        %{
          query: [
            dateFrom: "2017-01-01T00:00:00.000000Z",
            perPage: 100,
            page: 1,
            view: "Detailed"
          ]
        } ->
          %Tesla.Env{status: 200, body: %{"records" => "good"}}
      end)

      assert RingCentral.get_call_log() == "good"
    end

    test "overrides query params if values are provided" do
      date_from = Enum.random(0..1000)
      per_page = Enum.random(0..100)
      page = Enum.random(0..100)

      mock(fn
        %{query: [dateFrom: ^date_from, perPage: ^per_page, page: ^page, view: "Detailed"]} ->
          %Tesla.Env{status: 200, body: %{"records" => "good"}}
      end)

      assert RingCentral.get_call_log(date_from, per_page, page) == "good"
    end

    test "returns list of log entries" do
      rsp =
        %{response: "very good"}
        |> List.duplicate(10)

      mock(fn
        _ -> %Tesla.Env{status: 200, body: %{"records" => rsp}}
      end)

      assert [_ | _] = surveys = RingCentral.get_call_log()
      assert length(surveys) == 10
      assert %{} = List.first(surveys)
    end
  end
end
