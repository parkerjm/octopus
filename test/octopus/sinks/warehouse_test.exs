defmodule Octopus.Sink.WarehouseTest do
  use Octopus.DataCase
  alias Octopus.Sink.Warehouse

  defp test_table_exists? do
    length(test_table_rows()) > 0
  end

  defp test_table_rows do
    Ecto.Adapters.SQL.query!(
      Octopus.Repo,
      "SELECT column_name FROM information_schema.columns where table_schema = $1 and table_name = $2",
      ["public", "test_table"]
    )
    |> Map.get(:rows)
    |> List.flatten()
  end

  defp test_table_values do
    res = Ecto.Adapters.SQL.query!(Octopus.Repo, "SELECT * from test_table")
    cols = res.columns
    vals = List.flatten(res.rows)
    Enum.zip(cols, vals)
  end

  describe "#store" do
    setup do
      Ecto.Adapters.SQL.query(Octopus.Repo, "DROP TABLE test_table")
      refute test_table_exists?()

      :ok
    end

    test "creates table with given name if it doesn't exist" do
      Warehouse.store([%{"test_col" => "test_val"}], "test_table")
      assert test_table_exists?()
    end

    test "updates table schema if it exists but data contains new columns" do
      Warehouse.store([%{"test_col" => "test_val"}], "test_table")
      assert test_table_exists?()
      assert ["test_col"] = test_table_rows()

      Warehouse.store([%{"test_col" => "test_val", "test_col_2" => "test_val_2"}], "test_table")
      assert ["test_col", "test_col_2"] = test_table_rows()
    end

    test "maps JSON to database columns/values correctly" do
      ~s"""
      [
        {
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
          "permissions": ["read", "write"]
        }
        ]
      """
      |> Jason.decode!()
      |> Warehouse.store("test_table")

      expected = [
        {"cars_0_features_0_tires", "race"},
        {"cars_0_features_1_doors", "2"},
        {"cars_0_features_2_engine_0_cyls", "8"},
        {"cars_0_features_2_engine_1_liters", "4.0"},
        {"cars_0_features_3_drive_on", "road, track"},
        {"cars_0_name", "McLaren 720S"},
        {"cars_1_features_0_tires", "barely"},
        {"cars_1_features_1_doors", "1"},
        {"cars_1_features_2_engine_0_cyls", "1"},
        {"cars_1_features_2_engine_1_liters", "0.049"},
        {"cars_1_features_3_drive_on", "road"},
        {"cars_1_name", "Peel P50"},
        {"owner_created_at", "494039300"},
        {"owner_name", "James"},
        {"owner_tags", "seller, buyer"},
        {"permissions", "read, write"},
        {"version", "1"}
      ]

      assert test_table_values() == expected
    end
  end
end
