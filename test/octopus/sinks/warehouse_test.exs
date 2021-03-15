defmodule Octopus.Sink.WarehouseTest do
  use Octopus.DataCase
  alias Octopus.Sink.Warehouse

  describe "#store" do
    setup do
      Ecto.Adapters.SQL.query(Octopus.Repo, "DROP TABLE test_table")
      refute test_table_exists?()

      :ok
    end

    test "creates table with given name if it doesn't exist" do
      Warehouse.store([%{"id" => "test_val"}], "test_table")
      assert test_table_exists?()
    end

    test "updates table schema if it exists but data contains new columns" do
      Warehouse.store([%{"id" => "test_val"}], "test_table")
      assert test_table_exists?()
      assert ["id"] = test_table_cols()

      Warehouse.store([%{"id" => "test_val", "test_col" => "test_val_2"}], "test_table")
      assert ["id", "test_col"] = test_table_cols()
    end

    test "on create, maps JSON to database columns/values correctly" do
      expected_id = Enum.random(0..10000) |> to_string()

      expected_id
      |> sample_attributes()
      |> Jason.decode!()
      |> Warehouse.store("test_table")

      assert actual = Octopus.Repo.get(Octopus.TestTable, expected_id)

      actual_attributes =
        actual
        |> Map.from_struct()
        |> Map.delete(:__meta__)

      expected_attributes = %{
        cars_0_features_0_tires: "race",
        cars_0_features_1_doors: "2",
        cars_0_features_2_engine_0_cyls: "8",
        cars_0_features_2_engine_1_liters: "4.0",
        cars_0_features_3_drive_on: "road, track",
        cars_0_name: "McLaren 720S",
        cars_1_features_0_tires: "barely",
        cars_1_features_1_doors: "1",
        cars_1_features_2_engine_0_cyls: "1",
        cars_1_features_2_engine_1_liters: "0.049",
        cars_1_features_3_drive_on: "road",
        cars_1_name: "Peel P50",
        comment_with_trailing_single_quotes: "a'''",
        id: expected_id,
        long_field: String.duplicate("a ", 250),
        null_field: nil,
        owner_created_at: "494039300",
        owner_name: "James",
        owner_tags: "seller, buyer",
        permissions: "read, write",
        version: "1"
      }

      assert actual_attributes == expected_attributes
    end

    test "on update, maps JSON to database columns/values correctly" do
      expected_id = Enum.random(0..10000) |> to_string()

      %{"id" => expected_id}
      |> List.wrap()
      |> Warehouse.store("test_table")

      assert Octopus.Repo.get(Octopus.TestTable, expected_id)

      expected_id
      |> sample_attributes()
      |> Jason.decode!()
      |> List.first()
      |> Map.merge(%{
        "owner" => %{
          "name" => "Jeff",
          "created_at" => 494_039_483,
          "tags" => ["buyer"]
        }
      })
      |> List.wrap()
      |> Warehouse.store("test_table")

      assert actual = Octopus.Repo.get(Octopus.TestTable, expected_id)

      actual_attributes =
        actual
        |> Map.from_struct()
        |> Map.delete(:__meta__)

      expected_attributes = %{
        cars_0_features_0_tires: "race",
        cars_0_features_1_doors: "2",
        cars_0_features_2_engine_0_cyls: "8",
        cars_0_features_2_engine_1_liters: "4.0",
        cars_0_features_3_drive_on: "road, track",
        cars_0_name: "McLaren 720S",
        cars_1_features_0_tires: "barely",
        cars_1_features_1_doors: "1",
        cars_1_features_2_engine_0_cyls: "1",
        cars_1_features_2_engine_1_liters: "0.049",
        cars_1_features_3_drive_on: "road",
        cars_1_name: "Peel P50",
        comment_with_trailing_single_quotes: "a'''",
        id: expected_id,
        long_field: String.duplicate("a ", 250),
        null_field: nil,
        owner_created_at: "494039483",
        owner_name: "Jeff",
        owner_tags: "buyer",
        permissions: "read, write",
        version: "1"
      }

      assert actual_attributes == expected_attributes
    end
  end

  defp test_table_exists? do
    length(test_table_cols()) > 0
  end

  defp test_table_cols do
    Ecto.Adapters.SQL.query!(
      Octopus.Repo,
      "SELECT column_name FROM information_schema.columns where table_schema = $1 and table_name = $2",
      ["public", "test_table"]
    )
    |> Map.get(:rows)
    |> List.flatten()
  end

  defp sample_attributes(id) do
    ~s"""
    [
      {
        "id": "#{id}",
        "version": 1,
        "owner": {
          "name": "James",
          "created_at": 494039300,
          "tags": ["seller", "buyer"]
        },
        "cars": [
          {
            "name": "McLaren 720S",
            "features": [
              { "tires": "race" },
              { "doors": "2" },
              {
                "engine": [
                  { "cyls": 8 },
                  { "liters": 4.0 }
                ]
              },
              {
                "drive_on": ["road", "track"]
              }
            ]
          },
          {
            "name": "Peel P50",
            "features": [
              { "tires": "barely" },
              { "doors": "1" },
              {
                "engine": [
                  { "cyls": 1 },
                  { "liters": 0.049 }
                ]
              },
              {
                "drive_on": ["road"]
              }
            ]
          }
          ],
          "permissions": ["read", "write"],
          "long_field": "#{String.duplicate("a\\r", 999)}",
          "comment_with_trailing_single_quotes": "a'''",
          "null_field": null
          }
      ]
    """
  end
end
