defmodule Octopus.ConnectorHistoryTest do
  use Octopus.DataCase
  alias Octopus.ConnectorHistory

  @last_update Enum.random(0..1_000_000)

  @valid_attrs %{
    connector: to_string(__MODULE__),
    last_update: @last_update
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

    test "invalid when last_update not present" do
      changeset =
        ConnectorHistory.changeset(%ConnectorHistory{}, %{@valid_attrs | last_update: nil})

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

    test "invalid when last_update time is LT 0" do
      changeset =
        ConnectorHistory.changeset(%ConnectorHistory{}, %{@valid_attrs | last_update: -1})

      refute changeset.valid?
    end
  end

  describe "#get_history" do
    test "returns the history for the module name" do
      %ConnectorHistory{}
      |> ConnectorHistory.changeset(@valid_attrs)
      |> Repo.insert!()

      assert %ConnectorHistory{last_update: @last_update} =
               ConnectorHistory.get_history(__MODULE__)
    end

    test "returns empty struct when no history found" do
      assert %ConnectorHistory{} = ConnectorHistory.get_history(NotFoundModule)
    end
  end

  describe "#update_last_run_time" do
    test "updates runtime in database and returns struct with latest data" do
      %ConnectorHistory{}
      |> ConnectorHistory.changeset(@valid_attrs)
      |> Repo.insert!()

      new_last_update = Enum.random(0..1_000_000)
      result = ConnectorHistory.update_last_run_time(__MODULE__, new_last_update)

      assert %ConnectorHistory{last_update: ^new_last_update} = result

      assert %ConnectorHistory{last_update: ^new_last_update} =
               ConnectorHistory.get_history(__MODULE__)
    end

    test "creates history in db with correct last update time if it doesn't exist" do
      Repo.delete_all(ConnectorHistory)

      new_last_update = Enum.random(0..1_000_000)
      ConnectorHistory.update_last_run_time(__MODULE__, new_last_update)

      assert %ConnectorHistory{last_update: ^new_last_update} =
               ConnectorHistory.get_history(__MODULE__)
    end

    test "raises error if invalid last_update time is given" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        ConnectorHistory.update_last_run_time(__MODULE__, -1)
      end
    end

    test "raises error if no module is given" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        ConnectorHistory.update_last_run_time(nil, -1)
      end
    end
  end
end
