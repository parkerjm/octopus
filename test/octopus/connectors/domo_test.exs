defmodule Octopus.Connector.DomoTest do
  use Octopus.DataCase

  import Mox
  import Rewire

  alias Octopus.ConnectorHistory
  alias Octopus.Client.DomoMock
  alias Octopus.Client.HubspotMock
  alias Octopus.Connector.Domo

  rewire(Domo, Domo: DomoMock)
  rewire(Domo, Hubspot: HubspotMock)

  setup :verify_on_exit!

  setup do
    latest_record_date = "2021-01-#{Enum.random(10..31)}"
    ConnectorHistory.update_latest_record_date(to_string(Domo), latest_record_date)

    stub(DomoMock, :get_procurement_data, fn _, _ -> procurement_data() end)
    stub(HubspotMock, :store_procurement_data, fn data -> data end)

    {:ok, latest_record_date: latest_record_date}
  end

  describe "#perform" do
    test "connector pulls surveys from last update time", %{
      latest_record_date: latest_record_date
    } do
      expect(DomoMock, :get_procurement_data, fn ^latest_record_date, _ ->
        procurement_data()
      end)

      Domo.perform(%{})
    end

    test "it stores the results in hubspot" do
      data = procurement_data()
      expect(HubspotMock, :store_procurement_data, fn ^data -> data end)

      Domo.perform(%{})
    end

    test "fetches pages until fewer than max results are returned" do
      DomoMock
      |> expect_get_procurement_data(1000)
      |> expect_get_procurement_data(1000)
      |> expect_get_procurement_data(3)

      Domo.perform(%{})
    end

    test "sends all pages to hubspot" do
      DomoMock
      |> expect_get_procurement_data(1000)
      |> expect_get_procurement_data(3)

      expect(HubspotMock, :store_procurement_data, 2, fn data -> data end)

      Domo.perform(%{})
    end

    test "last update date is stored in connector history" do
      new_latest_record_date = Date.new!(2021, 3, Enum.random(1..30))

      stub(DomoMock, :get_procurement_data, fn _, _ ->
        [%{"Procurement_Lead_Submission_Date_1" => Date.to_string(new_latest_record_date)}]
      end)

      Domo.perform(%{})

      assert %ConnectorHistory{latest_record_date: ^new_latest_record_date} =
               ConnectorHistory.get_history(Domo)
    end
  end

  defp procurement_data do
    [
      %{
        "Procurement_Lead_Submission_Date_1" => "2020-01-01"
      }
    ]
  end

  defp expect_get_procurement_data(mock, result_count) do
    expect(mock, :get_procurement_data, fn _, _ ->
      List.duplicate(%{"Procurement_Lead_Submission_Date_1" => "2020-02-12"}, result_count)
    end)

    mock
  end
end
