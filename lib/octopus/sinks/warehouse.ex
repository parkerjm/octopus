defmodule Octopus.Sink.Warehouse do
  @behaviour Octopus.Sink

  @impl true
  def store(data, table) do
    data
    |> Enum.map(&generate_changesets/1)
    |> refresh_table_schema(table)
    |> Enum.each(fn changeset -> persist(changeset, table) end)

    data
  end

  defp refresh_table_schema(changesets, table) do
    columns = changesets |> Enum.reduce([], &field_names/2) |> Enum.uniq()

    Ecto.Adapters.SQL.query!(
      Octopus.Repo,
      "SELECT column_name FROM information_schema.columns where table_schema = $1 and table_name = $2",
      ["public", table]
    )
    |> Map.get(:rows)
    |> List.flatten()
    |> case do
      [] -> create_table(table, columns)
      existing_columns -> create_columns(table, columns -- existing_columns)
    end

    changesets
  end

  defp create_table(_table, []), do: :ok

  defp create_table(table, columns) do
    columns
    |> Enum.map(fn col -> "#{col} varchar(255)" end)
    |> Enum.join(",")
    |> (&Octopus.Repo.query!("CREATE TABLE #{table} (#{&1});")).()
  end

  defp create_columns(_table, []), do: :ok

  defp create_columns(table, columns) do
    columns
    |> Enum.map(fn col -> "ADD COLUMN #{col} varchar(255)" end)
    |> Enum.join(",")
    |> (&Octopus.Repo.query!("ALTER TABLE #{table} #{&1};")).()
  end

  defp persist(changeset, table) do
    cols = changeset |> Map.keys() |> Enum.join(",")
    vals = changeset |> Map.values() |> Enum.map(&map_value/1) |> Enum.join(",")
    Octopus.Repo.query!("INSERT INTO #{table} (#{cols}) VALUES (#{vals});")
  end

  defp map_value(nil), do: "''"

  defp map_value(val),
    do: "'#{val |> to_string |> String.replace("'", "''") |> String.slice(0, 254)}'"

  defp field_names(changeset, cols) do
    changeset |> Map.keys() |> Enum.map(&to_string/1) |> Kernel.++(cols)
  end

  defp generate_changesets(data, prefixes \\ []) when is_map(data) do
    data
    |> Map.keys()
    |> Enum.reduce(%{}, fn field, changeset ->
      cond do
        is_map(data[field]) ->
          generate_changesets(data[field], prefixes ++ [field])
          |> Map.merge(changeset)

        is_list(data[field]) && data[field] |> List.first() |> is_binary() ->
          data[field]
          |> Enum.join(", ")
          |> (&Map.put(%{}, field, &1)).()
          |> generate_changesets(prefixes)
          |> Map.merge(changeset)

        is_list(data[field]) ->
          data[field]
          |> Enum.with_index()
          |> Enum.flat_map(fn {item, idx} ->
            generate_changesets(item, prefixes ++ [field, idx])
          end)
          |> Enum.reduce(changeset, fn {col, value}, acc -> Map.put(acc, col, value) end)

        true ->
          case prefixes do
            [] -> field
            [_ | _] -> "#{Enum.join(prefixes, "_")}_#{field}"
          end
          |> String.replace(~r/[\(\)\/]/, "")
          |> String.replace("#", "number")
          |> Recase.to_snake()
          |> String.to_atom()
          |> (&Map.put(changeset, &1, data[field])).()
      end
    end)
  end
end
