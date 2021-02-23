defmodule Octopus.Sink.Warehouse do
  @behaviour Octopus.Sink

  @max_column_length 500

  @impl true
  def store(data, table) do
    data
    |> Enum.map(&generate_changesets/1)
    |> refresh_table_schema(table)
    |> refresh_ecto_schema(table)
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

  defp field_names(changeset, cols) do
    changeset |> Map.keys() |> Enum.map(&to_string/1) |> Kernel.++(cols)
  end

  defp create_table(_table, []), do: :ok

  defp create_table(table, columns) do
    columns
    |> Enum.map(fn col -> "#{col} varchar(#{@max_column_length})" end)
    |> Enum.join(",")
    |> (&Octopus.Repo.query!("CREATE TABLE #{table} (#{&1});")).()
  end

  defp create_columns(_table, []), do: :ok

  defp create_columns(table, columns) do
    columns
    |> Enum.map(fn col -> "ADD COLUMN #{col} varchar(#{@max_column_length})" end)
    |> Enum.join(",")
    |> (&Octopus.Repo.query!("ALTER TABLE #{table} #{&1};")).()
  end

  # TODO test
  # current: recreate module entirely on the fly
  # option: create modules one time, update schema on the fly? gets rid of warnings
  # Module.eval_quoted ^
  defp refresh_ecto_schema(changesets, table) do
    module = table |> Recase.to_pascal() |> (&Module.concat([Octopus, &1])).()

    fields =
      changesets
      |> Enum.reduce([], &field_names/2)
      |> Enum.uniq()
      |> remove_existing_fields(module)

    contents =
      quote do
        use Ecto.Schema

        @primary_key {:id, :string, []}
        schema unquote(table) do
          for field_name <- unquote(fields), do: field(String.to_atom(field_name), :string)
        end
      end

    Module.create(module, contents, Macro.Env.location(__ENV__))

    changesets
  end

  defp remove_existing_fields(fields, module) do
    fields --
      case Code.ensure_compiled(module) do
        {:module, _} -> module.__schema__(:fields) |> Enum.map(&to_string/1)
        _ -> ["id"]
      end
  end

  defp persist(changeset, table) do
    cols = changeset |> Map.keys() |> Enum.join(",")
    vals = changeset |> Map.values() |> Enum.map(&map_value/1) |> Enum.join(",")

    # check existing

    Octopus.Repo.query!("INSERT INTO #{table} (#{cols}) VALUES (#{vals});")
  end

  defp map_value(nil), do: "''"

  ##
  # transformations:
  # 1) convert all single quotes to double single quotes to meet Postgres syntax
  # 2) remove all whitespace chars with spaces as these can be inserted as two chars (i.e. "\r") in the database
  # 3) trim string to max length of 500
  # 4) strip trailing single quotes since they are not useful information and can violate Postgres query syntax
  # 5) finally, wrap the result in single quotes to meet Postgres syntax
  defp map_value(val) do
    val
    |> to_string
    |> String.replace("'", "''")
    |> String.replace(~r/\s+/, " ")
    |> String.slice(0, @max_column_length)
    |> String.replace(~r/'+$/, "")
    |> (&"'#{&1}'").()
  end

  defp generate_changesets(data, prefixes \\ []) when is_map(data) do
    data
    |> Map.keys()
    |> Enum.reduce(%{}, fn field, changeset ->
      cond do
        is_map(data[field]) ->
          generate_changesets(data[field], prefixes ++ [field])
          |> Map.merge(changeset)

        # TODO what if first is a number? can json have number lists?
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
