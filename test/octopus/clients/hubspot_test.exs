defmodule Octopus.Client.HubspotTest do
  use Octopus.DataCase
  import Tesla.Mock
  alias Octopus.Client.Hubspot

  describe "#store_procurement_data" do
    test "posts to correct URL" do
      expected_url = "https://api.hubapi.com/contacts/v1/contact/batch/"

      mock(fn
        %{method: :post, url: ^expected_url} -> {202, %{}, ""}
        _ -> {500, %{}, %{}}
      end)

      Hubspot.store_procurement_data(sample_data())
    end

    test "includes hubspot api key as a query param" do
      expected_api_key = Application.fetch_env!(:octopus, :hubspot)[:api_key]
      assert expected_api_key != nil

      mock(fn
        %{query: [hapikey: ^expected_api_key]} -> {202, %{}, ""}
        _ -> {500, %{}, %{}}
      end)

      Hubspot.store_procurement_data(sample_data())
    end

    test "correctly formats request body" do
      mock(fn
        req ->
          contacts = req.body |> Jason.decode!()
          assert length(contacts) == 2

          contact = List.first(contacts)
          assert contact["email"] == "test@example.com"
          assert is_list(contact["properties"])

          assert contact["properties"] == [
                   %{"property" => "Email", "value" => "test@example.com"},
                   %{"property" => "key1", "value" => "val1"},
                   %{"property" => "key2", "value" => "val2"},
                   %{"property" => "some_date", "value" => 1_597_190_400_000}
                 ]

          {202, %{}, ""}
      end)

      Hubspot.store_procurement_data(sample_data())
    end

    test "returns same data function is given" do
      mock(fn _ -> {202, %{}, ""} end)

      assert Hubspot.store_procurement_data(sample_data()) == sample_data()
    end

    test "raises error if no token is returned" do
      mock(fn _ -> raise RuntimeError, "request failed" end)

      assert_raise RuntimeError, ~r/request failed/, fn ->
        Hubspot.store_procurement_data(sample_data())
      end
    end

    test "batch request is retried with invalid emails removed" do
      data =
        sample_data() ++
          [
            %{"Email" => "invalid@example.com", "key1" => "val"},
            %{"Email" => "invalid2@example.com", "key1" => "val"}
          ]

      assert length(data) == 4

      mock(fn req ->
        body = Jason.decode!(req.body)

        case length(body) do
          4 -> {400, %{}, error_response()}
          3 -> {500, %{}, ""}
          2 -> {202, %{}, ""}
        end
      end)

      Hubspot.store_procurement_data(data)
    end
  end

  defp sample_data do
    [
      %{
        "Email" => "test@example.com",
        "key1" => "val1",
        "key2" => "val2",
        "some_date" => "2020-08-12"
      },
      %{
        "Email" => "test2@example.com",
        "key1" => "val4",
        "key2" => "val5",
        "some_date" => "2020-09-13"
      }
    ]
  end

  defp error_response do
    %{
      "correlationId" => "f23b4efa-c15c-4032-b128-f0ab146f1354",
      "failureMessages" => [
        %{
          "index" => 2,
          "propertyValidationResult" => %{
            "error" => "INVALID_EMAIL",
            "isValid" => false,
            "message" => "Email address invalid@example.com is invalid",
            "name" => "email"
          }
        },
        %{
          "index" => 3,
          "propertyValidationResult" => %{
            "error" => "INVALID_EMAIL",
            "isValid" => false,
            "message" => "Email address invalid2@example.com is invalid",
            "name" => "email"
          }
        }
      ],
      "invalidEmails" => ["invalid@example.com", "invalid2@example.com"],
      "message" => "Errors found processing batch update",
      "status" => "error"
    }
  end
end
