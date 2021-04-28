defmodule Octopus.Client.DelightedTest do
  use Octopus.DataCase
  alias Octopus.Client.Delighted

  setup do
    bypass = Bypass.open()

    :octopus
    |> Application.get_env(:delighted)
    |> Keyword.put(:base_url, "http://localhost:#{bypass.port}")
    |> (&Application.put_env(:octopus, :delighted, &1)).()

    {:ok, bypass: bypass}
  end

  describe "#get_survey_responses" do
    test "sends GET request to correct request URL", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/survey_responses.json", fn conn ->
        survey_response(conn)
      end)

      Delighted.get_survey_responses()
    end

    test "includes base 64 encoded API key in request", %{bypass: bypass} do
      expected_auth_header = "Basic #{Base.encode64("fake_api_key:")}"

      Bypass.expect(bypass, "GET", "/survey_responses.json", fn conn ->
        assert :proplists.get_value("authorization", conn.req_headers) == expected_auth_header
        survey_response(conn)
      end)

      Delighted.get_survey_responses()
    end

    test "defaults query params to correct values", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/survey_responses.json", fn conn ->
        assert conn.query_params["updated_since"] == "0"
        assert conn.query_params["per_page"] == "100"
        assert conn.query_params["expand"] == ["person", "notes"]

        survey_response(conn)
      end)

      Delighted.get_survey_responses()
    end

    test "overrides query params if values are provided", %{bypass: bypass} do
      updated_since = Enum.random(0..1000)
      per_page = Enum.random(0..100)

      Bypass.expect(bypass, "GET", "/survey_responses.json", fn conn ->
        assert conn.query_params["updated_since"] == to_string(updated_since)
        assert conn.query_params["per_page"] == to_string(per_page)
        assert conn.query_params["expand"] == ["person", "notes"]

        survey_response(conn)
      end)

      Delighted.get_survey_responses(updated_since, per_page)
    end

    test "returns list of survey responses", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/survey_responses.json", fn conn ->
        survey_response(conn)
      end)

      assert [_ | _] = surveys = Delighted.get_survey_responses()
      assert length(surveys) == 10
      assert %{} = List.first(surveys)
    end
  end

  defp survey_response(conn) do
    surveys = %{response: "very good"} |> List.duplicate(10) |> Jason.encode!()

    conn
    |> Plug.Conn.put_resp_header("content-type", "application/json")
    |> Plug.Conn.resp(200, surveys)
  end
end
