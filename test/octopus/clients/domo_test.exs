defmodule Octopus.Client.DomoTest do
  use Octopus.DataCase
  import Mox
  import Rewire
  alias Octopus.Client.{Domo, DomoAuthMock}

  rewire(Domo, DomoAuth: DomoAuthMock)

  setup :verify_on_exit!

  setup do
    bypass = Bypass.open()

    :octopus
    |> Application.get_env(:domo)
    |> Keyword.put(:base_url, "http://localhost:#{bypass.port}")
    |> (&Application.put_env(:octopus, :domo, &1)).()

    stub(DomoAuthMock, :get_token, fn -> "token" end)

    {:ok, bypass: bypass}
  end

  describe "#get_procurement_data" do
    test "sends POST request to correct request URL", %{
      bypass: bypass
    } do
      original_dataset_id = Application.get_env(:octopus, :domo)[:procurement_dataset_id]
      procurement_dataset_id = Ecto.UUID.generate()
      expected_url = "/v1/datasets/query/execute/#{procurement_dataset_id}"

      :octopus
      |> Application.get_env(:domo)
      |> Keyword.put(:procurement_dataset_id, procurement_dataset_id)
      |> (&Application.put_env(:octopus, :domo, &1)).()

      Bypass.expect(bypass, "POST", expected_url, fn conn ->
        procurement_data_response(conn)
      end)

      Domo.get_procurement_data()

      :octopus
      |> Application.get_env(:domo)
      |> Keyword.put(:procurement_dataset_id, original_dataset_id)
      |> (&Application.put_env(:octopus, :domo, &1)).()
    end

    test "includes generated bearer token in auth header", %{bypass: bypass} do
      expected_token = "token#{Enum.random(0..1000)}"
      expected_auth_header = "Bearer #{expected_token}"

      stub(DomoAuthMock, :get_token, fn -> expected_token end)

      Bypass.expect(bypass, "POST", "/v1/datasets/query/execute/fake_dataset_id", fn conn ->
        assert :proplists.get_value("authorization", conn.req_headers) == expected_auth_header

        procurement_data_response(conn)
      end)

      Domo.get_procurement_data()
    end

    test "sends query in body", %{bypass: bypass} do
      expected_limit = Enum.random(0..1000)
      expected_date = "2021-01-#{Enum.random(1..31)}"

      expected_body =
        "{\"sql\":\"SELECT * FROM table\\n WHERE Procurement_Lead_Submission_Date_1 >= '#{
          expected_date
        }'\\n ORDER BY Procurement_Lead_Submission_Date_1 ASC\\n LIMIT #{expected_limit}\\n\"}"

      Bypass.expect(bypass, "POST", "/v1/datasets/query/execute/fake_dataset_id", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == expected_body

        procurement_data_response(conn)
      end)

      Domo.get_procurement_data(expected_date, expected_limit)
    end

    test "returns list of elixir maps", %{bypass: bypass} do
      expected_return = [
        %{"col1" => "val1-1", "col2" => "val1-2", "col3" => "val1-3"},
        %{"col1" => "val2-1", "col2" => "val2-2", "col3" => "val2-3"},
        %{"col1" => "val3-1", "col2" => "val3-2", "col3" => "val3-3"}
      ]

      Bypass.expect(bypass, "POST", "/v1/datasets/query/execute/fake_dataset_id", fn conn ->
        procurement_data_response(conn)
      end)

      assert Domo.get_procurement_data() == expected_return
    end

    test "raises error if response code is not 200", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/v1/datasets/query/execute/fake_dataset_id", fn conn ->
        Plug.Conn.resp(conn, 500, "")
      end)

      assert_raise MatchError, fn -> Domo.get_procurement_data() end
    end
  end

  defp procurement_data_response(conn) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/json")
    |> Plug.Conn.resp(200, Jason.encode!(procurement_data()))
  end

  defp procurement_data do
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
