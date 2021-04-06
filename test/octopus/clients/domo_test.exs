defmodule Octopus.Client.DomoTest do
  use Octopus.DataCase
  import Mox
  import Rewire
  import Tesla.Mock
  alias Octopus.Client.{Domo, DomoAuthMock}

  rewire(Domo, DomoAuth: DomoAuthMock)

  setup :verify_on_exit!

  setup do
    stub(DomoAuthMock, :get_token, fn -> "token" end)
    :ok
  end

  describe "#get_procurement_data" do
    setup do
      procurement_dataset_id = Ecto.UUID.generate()

      :octopus
      |> Application.get_env(:domo)
      |> Keyword.put(:procurement_dataset_id, procurement_dataset_id)
      |> (&Application.put_env(:octopus, :domo, &1)).()

      {:ok, procurement_dataset_id: procurement_dataset_id}
    end

    test "sends GET request to correct request URL", %{
      procurement_dataset_id: procurement_dataset_id
    } do
      expected_url = "https://api.domo.com/v1/datasets/query/execute/#{procurement_dataset_id}"

      mock(fn
        %{method: :post, url: ^expected_url} ->
          {200, %{}, fake_rsp()}
      end)

      Domo.get_procurement_data("2021-01-01", 1)
    end

    test "includes generated bearer token in auth header" do
      expected_token = "token#{Enum.random(0..1000)}"
      expected_auth_header = "Bearer #{expected_token}"

      stub(DomoAuthMock, :get_token, fn -> expected_token end)

      mock(fn
        %{headers: [{"authorization", ^expected_auth_header} | _rest]} ->
          {200, %{}, fake_rsp()}
      end)

      Domo.get_procurement_data("2021-01-01", 1)
    end

    test "sends query in body" do
      expected_limit = Enum.random(0..1000)
      expected_date = "2021-01-#{Enum.random(1..31)}"

      expected_body =
        "{\"sql\":\"SELECT * FROM table\\n WHERE Procurement_Lead_Submission_Date_1 >= '#{
          expected_date
        }'\\n ORDER BY Procurement_Lead_Submission_Date_1 ASC\\n LIMIT #{expected_limit}\\n\"}"

      mock(fn
        %{body: ^expected_body} ->
          {200, %{}, fake_rsp()}
      end)

      Domo.get_procurement_data(expected_date, expected_limit)
    end

    test "returns list of elixir maps" do
      mock(fn
        _ ->
          {200, %{}, fake_rsp()}
      end)

      expected_return = [
        %{"col1" => "val1-1", "col2" => "val1-2", "col3" => "val1-3"},
        %{"col1" => "val2-1", "col2" => "val2-2", "col3" => "val2-3"},
        %{"col1" => "val3-1", "col2" => "val3-2", "col3" => "val3-3"}
      ]

      assert Domo.get_procurement_data("2021-01-01", 1) == expected_return
    end

    test "raises error if response code is not 200" do
      mock(fn
        _ ->
          raise RuntimeError, "request error"
          # {500, %{}, %{}}
      end)

      assert_raise RuntimeError, ~r/request error/, fn ->
        Domo.get_procurement_data("2021-01-01", 1)
      end
    end
  end

  defp fake_rsp do
    %{
      "columns" => ["col1", "col2", "col3"],
      "rows" => [
        ["val1-1", "val1-2", "val1-3"],
        ["val2-1", "val2-2", "val2-3"],
        ["val3-1", "val3-2", "val3-3"]
      ]
    }
  end
end
