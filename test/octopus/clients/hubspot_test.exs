defmodule Octopus.Client.HubspotTest do
  use Octopus.DataCase, async: true
  alias Octopus.Client.Hubspot

  @sample_procurement_data [
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

  @error_response %{
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

  setup do
    bypass = Bypass.open()

    :octopus
    |> Application.get_env(:hubspot)
    |> Keyword.put(:base_url, "http://localhost:#{bypass.port}")
    |> (&Application.put_env(:octopus, :hubspot, &1)).()

    {:ok, bypass: bypass}
  end

  describe "#get_contacts" do
    defp contacts_response(conn) do
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, sample_contacts())
    end

    defp sample_contacts do
      Jason.encode!(%{
        "results" => [
          %{
            "id" => "203121246",
            "properties" => %{
              "createdate" => "2019-10-21T12:29:17.341Z",
              "hs_object_id" => "203121246",
              "lastmodifieddate" => "2020-10-08T05:39:07.673Z"
            },
            "createdAt" => "2019-10-21T12:29:17.341Z",
            "updatedAt" => "2020-10-08T05:39:07.673Z",
            "archived" => false
          },
          %{
            "id" => "176588001",
            "properties" => %{
              "createdate" => "2019-07-31T18:59:24.947Z",
              "hs_object_id" => "176588001",
              "lastmodifieddate" => "2020-10-17T04:46:58.238Z"
            },
            "createdAt" => "2019-07-31T18:59:24.947Z",
            "updatedAt" => "2020-10-17T04:46:58.238Z",
            "archived" => false
          }
        ]
      })
    end

    defp sample_contact_properties do
      Jason.encode!([
        %{"name" => "prop1"},
        %{"name" => "prop2"},
        %{"name" => "prop3"}
      ])
    end

    setup %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/properties/v1/contacts/properties", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, sample_contact_properties())
      end)

      Bypass.stub(bypass, "POST", "/crm/v3/objects/contacts/search", fn conn ->
        contacts_response(conn)
      end)

      :ok
    end

    test "posts to correct URL", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/crm/v3/objects/contacts/search", fn conn ->
        contacts_response(conn)
      end)

      Hubspot.get_contacts()
    end

    test "includes hubspot api key as a query param", %{bypass: bypass} do
      expected_api_key = Application.fetch_env!(:octopus, :hubspot)[:api_key]
      assert expected_api_key != nil

      Bypass.expect(bypass, "POST", "/crm/v3/objects/contacts/search", fn conn ->
        assert conn.query_params["hapikey"] == expected_api_key
        contacts_response(conn)
      end)

      Hubspot.get_contacts()
    end

    test "filters by input timestamp", %{bypass: bypass} do
      timestamp = Enum.random(0..10_000_000_000)

      Bypass.expect(bypass, "POST", "/crm/v3/objects/contacts/search", fn conn ->
        body = conn |> Plug.Conn.read_body() |> elem(1) |> Jason.decode!()

        %{"filterGroups" => [%{"filters" => [timestamp_filter]}]} = body

        assert timestamp_filter["propertyName"] == "lastmodifieddate"
        assert timestamp_filter["operator"] == "GT"
        assert timestamp_filter["value"] == timestamp

        contacts_response(conn)
      end)

      Hubspot.get_contacts(timestamp)
    end

    test "includes contact properties in request body", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/crm/v3/objects/contacts/search", fn conn ->
        body = conn |> Plug.Conn.read_body() |> elem(1) |> Jason.decode!()

        assert body["properties"] == ["prop1", "prop2", "prop3"]

        contacts_response(conn)
      end)

      Hubspot.get_contacts()
    end

    test "includes page limit in request body", %{bypass: bypass} do
      per_page = Enum.random(0..1000)

      Bypass.expect(bypass, "POST", "/crm/v3/objects/contacts/search", fn conn ->
        body = conn |> Plug.Conn.read_body() |> elem(1) |> Jason.decode!()

        assert body["limit"] == per_page

        contacts_response(conn)
      end)

      Hubspot.get_contacts(0, per_page)
    end

    test "includes sorting param in request body", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/crm/v3/objects/contacts/search", fn conn ->
        body = conn |> Plug.Conn.read_body() |> elem(1) |> Jason.decode!()

        assert body["sorts"] == ["lastmodifieddate"]

        contacts_response(conn)
      end)

      Hubspot.get_contacts()
    end

    test "fetches contact properties when none are cached", %{bypass: bypass} do
      Cachex.put(:cache, :hubspot_contact_properties, [1, 2, 3])

      Bypass.stub(bypass, "GET", "/properties/v1/contacts/properties", fn _conn ->
        raise "should not be called"
      end)

      Hubspot.get_contacts()

      Cachex.reset(:cache)
    end

    test "does not fetch contact properties if cached properties exist", %{bypass: bypass} do
      Cachex.reset(:cache)

      Bypass.expect(bypass, "GET", "/properties/v1/contacts/properties", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, sample_contact_properties())
      end)

      Hubspot.get_contacts()
    end

    test "returns contacts", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/crm/v3/objects/contacts/search", fn conn ->
        contacts_response(conn)
      end)

      assert Hubspot.get_contacts() ==
               sample_contacts() |> Jason.decode!() |> Access.get("results")
    end
  end

  describe "#get_email_events" do
    defp email_events_response(conn) do
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, sample_email_events())
    end

    defp sample_email_events do
      Jason.encode!(%{
        "offset" => "Ch8KFgi27JDEgL33h74BEKyCrYiAnOad8wEYgs-Cu5Uv",
        "events" => [
          %{
            "appId" => 20185,
            "appName" => "AbBatch",
            "browser" => %{
              "family" => "Safari mobile",
              "name" => "Safari mobile 14.0.3",
              "producer" => "Apple Inc.",
              "producerUrl" => "https://www.apple.com/",
              "type" => "Mobile Browser",
              "url" => "https://en.wikipedia.org/wiki/Safari_(web_browser)",
              "version" => ["14.0.3"]
            },
            "created" => 1_619_814_290_153,
            "deviceType" => "MOBILE",
            "emailCampaignGroupId" => 124_058_870,
            "emailCampaignId" => 124_058_870,
            "filteredEvent" => false,
            "id" => "865306bc-ec52-3a9a-b819-749c492ae4a8",
            "linkId" => 0,
            "location" => %{
              "city" => "weatherford",
              "country" => "UNITED STATES",
              "latitude" => 32.7566,
              "longitude" => -97.7906,
              "state" => "texas",
              "zipcode" => "76086"
            },
            "portalId" => 3_485_016,
            "recipient" => "srmarsh53@gmail.com",
            "referer" => "",
            "sentBy" => %{
              "created" => 1_619_800_753_158,
              "id" => "ae3ac14f-df25-4fba-9b6e-beb1a9a65609"
            },
            "smtpId" => nil,
            "type" => "CLICK",
            "url" =>
              "https://www.crownandcaliber.com/collections/clearance?kmi=srmarsh53%40gmail.com&utm_campaign=RolexSubmariners_ActiveCollection043021&utm_medium=email&_hsmi=124058870&utm_content=124058870&utm_source=hs_email",
            "userAgent" =>
              "Mozilla/5.0 (iPhone; CPU iPhone OS 14_4_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Mobile/15E148 Safari/604.1"
          }
        ]
      })
    end

    setup %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/email/public/v1/events", fn conn ->
        email_events_response(conn)
      end)

      :ok
    end

    test "posts to correct URL", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/email/public/v1/events", fn conn ->
        email_events_response(conn)
      end)

      Hubspot.get_email_events("CLICK", [])
    end

    test "includes hubspot api key as a query param", %{bypass: bypass} do
      expected_api_key = Application.fetch_env!(:octopus, :hubspot)[:api_key]
      assert expected_api_key != nil

      Bypass.stub(bypass, "GET", "/email/public/v1/events", fn conn ->
        assert conn.query_params["hapikey"] == expected_api_key
        email_events_response(conn)
      end)

      Hubspot.get_email_events("CLICK", [])
    end

    test "includes event type as a query param", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/email/public/v1/events", fn conn ->
        assert conn.query_params["eventType"] == "SOME_EVENT_TYPE"
        email_events_response(conn)
      end)

      Hubspot.get_email_events("SOME_EVENT_TYPE", [])
    end

    test "includes start timestamp as a query param", %{bypass: bypass} do
      expected_timestamp = DateTime.to_unix(DateTime.utc_now())

      Bypass.stub(bypass, "GET", "/email/public/v1/events", fn conn ->
        assert conn.query_params["startTimestamp"] == to_string(expected_timestamp)
        email_events_response(conn)
      end)

      Hubspot.get_email_events("CLICK", from_unix_timestamp: expected_timestamp)
    end

    test "includes limit as a query param", %{bypass: bypass} do
      expected_limit = Enum.random(0..1000)

      Bypass.stub(bypass, "GET", "/email/public/v1/events", fn conn ->
        assert conn.query_params["limit"] == to_string(expected_limit)
        email_events_response(conn)
      end)

      Hubspot.get_email_events("CLICK", per_page: expected_limit)
    end

    test "includes offset as query param", %{bypass: bypass} do
      expected_offset = "offset#{Enum.random(0..1000)}"

      Bypass.stub(bypass, "GET", "/email/public/v1/events", fn conn ->
        assert conn.query_params["offset"] == expected_offset
        email_events_response(conn)
      end)

      Hubspot.get_email_events("CLICK", offset: expected_offset)
    end

    test "returns offset and events", %{bypass: bypass} do
      Bypass.stub(bypass, "GET", "/email/public/v1/events", fn conn ->
        email_events_response(conn)
      end)

      %{"offset" => expected_offset, "events" => expected_events} =
        Jason.decode!(sample_email_events())

      assert Hubspot.get_email_events("CLICK", []) == %{
               offset: expected_offset,
               events: expected_events
             }
    end
  end

  describe "#store_procurement_data" do
    test "posts to correct URL", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/contacts/v1/contact/batch/", fn conn ->
        Plug.Conn.resp(conn, 202, "")
      end)

      Hubspot.store_procurement_data(@sample_procurement_data)
    end

    test "includes hubspot api key as a query param", %{bypass: bypass} do
      expected_api_key = Application.fetch_env!(:octopus, :hubspot)[:api_key]
      assert expected_api_key != nil

      Bypass.expect(bypass, "POST", "/contacts/v1/contact/batch/", fn conn ->
        assert conn.query_params["hapikey"] == expected_api_key

        Plug.Conn.resp(conn, 202, "")
      end)

      Hubspot.store_procurement_data(@sample_procurement_data)
    end

    test "correctly formats request body", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/contacts/v1/contact/batch/", fn conn ->
        contacts = conn |> Plug.Conn.read_body() |> elem(1) |> Jason.decode!()
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

        Plug.Conn.resp(conn, 202, "")
      end)

      Hubspot.store_procurement_data(@sample_procurement_data)
    end

    test "returns same data function is given", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/contacts/v1/contact/batch/", fn conn ->
        Plug.Conn.resp(conn, 202, "")
      end)

      assert Hubspot.store_procurement_data(@sample_procurement_data) ==
               @sample_procurement_data
    end

    test "batch request is retried with invalid emails removed", %{bypass: bypass} do
      data =
        @sample_procurement_data ++
          [
            %{"Email" => "invalid@example.com", "key1" => "val"},
            %{"Email" => "invalid2@example.com", "key1" => "val"}
          ]

      assert length(data) == 4

      Bypass.expect(bypass, "POST", "/contacts/v1/contact/batch/", fn conn ->
        body = conn |> Plug.Conn.read_body() |> elem(1) |> Jason.decode!()

        case length(body) do
          4 ->
            conn
            |> Plug.Conn.put_resp_header("content-type", "application/json")
            |> Plug.Conn.resp(400, Jason.encode!(@error_response))

          3 ->
            Plug.Conn.resp(conn, 500, "")

          2 ->
            Plug.Conn.resp(conn, 202, "")
        end
      end)

      Hubspot.store_procurement_data(data)
    end
  end
end
