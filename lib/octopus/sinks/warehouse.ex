defmodule Octopus.Sink.Warehouse do
  defmodule Behaviour do
    @callback store(list(map()), String.t()) :: list(map())
    @callback store(list(map()), String.t(), list(String.t())) :: list(map())
  end

  defmodule MissingIdError do
    defexception message: "entry is missing ID, unable to persist"
  end

  @behaviour Behaviour
  alias Octopus.Repo
  alias Octopus.Sink.Warehouse.MissingIdError
  import Ecto.Changeset, only: [cast: 3]

  @impl true
  def store(data, table, exclude_prefixes \\ []) do
    data
    |> Enum.map(&generate_param_sets(&1, exclude_prefixes))
    |> refresh_table_schema(table)
    |> refresh_ecto_schema(table)
    |> Task.async_stream(&persist(&1, table), timeout: :infinity)
    |> Stream.run()

    data
  end

  defp refresh_table_schema(params_sets, table) do
    columns = params_sets |> Enum.reduce([], &field_names/2) |> Enum.uniq()

    Repo.query!(
      "SELECT column_name FROM information_schema.columns where table_schema = $1 and table_name = $2",
      ["public", table]
    )
    |> Map.get(:rows)
    |> List.flatten()
    |> case do
      [] -> create_table(table, columns)
      existing_columns -> create_columns(table, columns -- existing_columns)
    end

    params_sets
  end

  defp field_names(params, cols) do
    params |> Map.keys() |> Enum.map(&to_string/1) |> Kernel.++(cols)
  end

  defp create_table(_table, []), do: :ok

  defp create_table(table, columns) do
    columns
    |> Enum.map(&"#{&1} varchar(#{CoercedString.max_length()})")
    |> Enum.join(",")
    |> (&Repo.query!("CREATE TABLE IF NOT EXISTS #{table} (#{&1});")).()

    Repo.query!("CREATE INDEX IF NOT EXISTS idx_#{table}_id ON #{table}(id)")
  end

  defp create_columns(_table, []), do: :ok

  defp create_columns(table, columns) do
    columns
    |> Enum.map(&"ADD COLUMN IF NOT EXISTS \"#{&1}\" varchar(#{CoercedString.max_length()})")
    |> Enum.join(",")
    |> (&Repo.query!("ALTER TABLE #{table} #{&1};")).()
  end

  defp refresh_ecto_schema(params_sets, table) do
    module = module_for_table(table)

    fields =
      params_sets
      |> Enum.reduce([], &field_names/2)
      |> Enum.uniq()
      |> List.delete("id")

    contents =
      quote do
        use Ecto.Schema

        @primary_key {:id, :string, []}
        schema unquote(table) do
          for field_name <- unquote(fields) do
            field(String.to_atom(field_name), CoercedString)
          end
        end

        def new() do
          %__MODULE__{}
        end
      end

    Module.create(module, contents, Macro.Env.location(__ENV__))

    params_sets
  end

  defp module_for_table(table) do
    table |> Recase.to_pascal() |> (&Module.concat([Octopus, &1])).()
  end

  defp persist(params, table) do
    with {:ok, id} <- Map.fetch(params, :id),
         {:ok, id} <- CoercedString.cast(id),
         %{} = existing <- Repo.get(module_for_table(table), id) do
      existing |> cast(params, Map.keys(params)) |> Repo.update()
    else
      :error ->
        raise MissingIdError

      nil ->
        table
        |> module_for_table()
        |> (& &1.new()).()
        |> cast(params, Map.keys(params))
        |> Repo.insert()
    end
  end

  defp generate_param_sets(data, exclude_prefixes, prefixes \\ []) when is_map(data) do
    data
    |> Map.keys()
    |> Enum.reduce(%{}, fn field, params ->
      cond do
        is_map(data[field]) ->
          generate_param_sets(data[field], exclude_prefixes, prefixes ++ [field])
          |> Map.merge(params)

        is_list(data[field]) && data[field] |> List.first() |> is_binary() ->
          data[field]
          |> Enum.join(", ")
          |> (&Map.put(%{}, field, &1)).()
          |> generate_param_sets(exclude_prefixes, prefixes)
          |> Map.merge(params)

        is_list(data[field]) ->
          data[field]
          |> Enum.with_index()
          |> Enum.flat_map(fn {item, idx} ->
            generate_param_sets(item, exclude_prefixes, prefixes ++ [field, idx])
          end)
          |> Enum.reduce(params, fn {col, value}, acc -> Map.put(acc, col, value) end)

        true ->
          case prefixes do
            [] -> map_field_name(field)
            [_ | _] -> map_field_name("#{Enum.join(prefixes -- exclude_prefixes, "_")}_#{field}")
          end
          |> String.replace(~r/[\(\)\/]/, "")
          |> String.replace("#", "number")
          |> Recase.to_snake()
          |> String.to_atom()
          |> (&Map.put(params, &1, data[field])).()
      end
    end)
  end

  # ensures field name is not longer than the postgres max identifier size
  defp map_field_name(field) do
    field
    |> to_string()
    |> String.slice(0..63)
  end
end
