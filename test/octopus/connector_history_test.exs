defmodule Octopus.ConnectorHistoryTest do
  use Octopus.DataCase
  alias Octopus.ConnectorHistory

  @latest_record_time_unix Enum.random(0..1_000_000)

  @valid_attrs %{
    connector: to_string(__MODULE__),
    latest_record_time_unix: @latest_record_time_unix
  }

  describe "#changeset" do
    test "valid for valid params" do
      changeset = ConnectorHistory.changeset(%ConnectorHistory{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid when connector not present" do
      changeset =
        ConnectorHistory.changeset(%ConnectorHistory{}, %{@valid_attrs | connector: nil})

      refute changeset.valid?
    end

    test "invalid when connector name is GT 250 chars" do
      too_long = String.duplicate("a", 251)

      changeset =
        ConnectorHistory.changeset(%ConnectorHistory{}, %{@valid_attrs | connector: too_long})

      refute changeset.valid?
    end

    test "invalid when connector name is LT 2 chars" do
      changeset =
        ConnectorHistory.changeset(%ConnectorHistory{}, %{@valid_attrs | connector: "a"})

      refute changeset.valid?
    end

    test "invalid when latest_record_time_unix time is LT 0" do
      changeset =
        ConnectorHistory.changeset(%ConnectorHistory{}, %{
          @valid_attrs
          | latest_record_time_unix: -1
        })

      refute changeset.valid?
    end
  end

  describe "#get_history" do
    test "returns the history for the module name" do
      %ConnectorHistory{}
      |> ConnectorHistory.changeset(@valid_attrs)
      |> Repo.insert!()

      assert %ConnectorHistory{latest_record_time_unix: @latest_record_time_unix} =
               ConnectorHistory.get_history(__MODULE__)
    end

    test "returns empty struct when no history found" do
      assert %ConnectorHistory{} = ConnectorHistory.get_history(NotFoundModule)
    end
  end

  describe "#update_latest_record_time_unix" do
    test "updates runtime in database and returns struct with latest data" do
      %ConnectorHistory{}
      |> ConnectorHistory.changeset(@valid_attrs)
      |> Repo.insert!()

      new_latest_record_time_unix = Enum.random(0..1_000_000)

      result =
        ConnectorHistory.update_latest_record_time_unix(__MODULE__, new_latest_record_time_unix)

      assert %ConnectorHistory{latest_record_time_unix: ^new_latest_record_time_unix} = result

      assert %ConnectorHistory{latest_record_time_unix: ^new_latest_record_time_unix} =
               ConnectorHistory.get_history(__MODULE__)
    end

    test "creates history in db with correct last update time if it doesn't exist" do
      Repo.delete_all(ConnectorHistory)

      new_latest_record_time_unix = Enum.random(0..1_000_000)
      ConnectorHistory.update_latest_record_time_unix(__MODULE__, new_latest_record_time_unix)

      assert %ConnectorHistory{latest_record_time_unix: ^new_latest_record_time_unix} =
               ConnectorHistory.get_history(__MODULE__)
    end

    test "raises error if invalid latest_record_time_unix time is given" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        ConnectorHistory.update_latest_record_time_unix(__MODULE__, -1)
      end
    end

    test "raises error if no module is given" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        ConnectorHistory.update_latest_record_time_unix(nil, -1)
      end
    end
  end

  describe "#update_latest_record_date" do
    test "updates runtime in database and returns struct with latest data" do
      %ConnectorHistory{}
      |> ConnectorHistory.changeset(%{
        connector: to_string(__MODULE__),
        latest_record_date: Date.utc_today()
      })
      |> Repo.insert!()

      new_latest_record_date = Date.new!(2021, 12, Enum.random(1..31))
      result = ConnectorHistory.update_latest_record_date(__MODULE__, new_latest_record_date)

      assert %ConnectorHistory{latest_record_date: ^new_latest_record_date} = result

      assert %ConnectorHistory{latest_record_date: ^new_latest_record_date} =
               ConnectorHistory.get_history(__MODULE__)
    end

    test "creates history in db with correct last update time if it doesn't exist" do
      Repo.delete_all(ConnectorHistory)

      new_latest_record_date = Date.new!(2021, 12, Enum.random(1..31))
      ConnectorHistory.update_latest_record_date(__MODULE__, new_latest_record_date)

      assert %ConnectorHistory{latest_record_date: ^new_latest_record_date} =
               ConnectorHistory.get_history(__MODULE__)
    end

    test "raises error if invalid latest_record_date time is given" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        ConnectorHistory.update_latest_record_date(__MODULE__, -1)
      end
    end

    test "raises error if no module is given" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        ConnectorHistory.update_latest_record_date(nil, -1)
      end
    end
  end
end
