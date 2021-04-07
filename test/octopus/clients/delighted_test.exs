defmodule Octopus.Client.DelightedTest do
  use Octopus.DataCase
  import Tesla.Mock
  alias Octopus.Client.Delighted

  describe "#get_survey_responses" do
    test "sends GET request to correct request URL" do
      mock(fn
        %{method: :get, url: "https://api.delighted.com/v1/survey_responses.json"} ->
          %Tesla.Env{status: 200, body: []}
      end)

      assert Delighted.get_survey_responses() == []
    end

    test "includes base 64 encoded API key in request" do
      mock(fn
        %{headers: [{"authorization", "Basic ZmFrZTo="}]} ->
          %Tesla.Env{status: 200, body: "authorized"}
      end)

      assert Delighted.get_survey_responses() == "authorized"
    end

    test "defaults query params to correct values" do
      mock(fn
        %{query: [updated_since: 0, per_page: 100, expand: ["person", "notes"]]} ->
          %Tesla.Env{status: 200, body: "good"}
      end)

      assert Delighted.get_survey_responses() == "good"
    end

    test "overrides query params if values are provided" do
      updated_since = Enum.random(0..1000)
      per_page = Enum.random(0..100)

      mock(fn
        %{
          query: [updated_since: ^updated_since, per_page: ^per_page, expand: ["person", "notes"]]
        } ->
          %Tesla.Env{status: 200, body: "good"}
      end)

      assert Delighted.get_survey_responses(updated_since, per_page) == "good"
    end

    test "returns list of survey responses" do
      rsp =
        %{response: "very good"}
        |> List.duplicate(10)

      mock(fn
        _ -> %Tesla.Env{status: 200, body: rsp}
      end)

      assert [_ | _] = surveys = Delighted.get_survey_responses()
      assert length(surveys) == 10
      assert %{} = List.first(surveys)
    end
  end
end
