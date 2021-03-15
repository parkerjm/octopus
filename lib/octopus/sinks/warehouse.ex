defmodule Octopus.Sink.Warehouse do
  @behaviour Octopus.Sink
  alias Octopus.Repo
  alias Octopus.Sink.Warehouse.MissingIdError
  import Ecto.Changeset, only: [cast: 3]

  defmodule MissingIdError do
    defexception message: "entry is missing ID, unable to persist"
  end

  @impl true
  def store(data, table) do
    data
    |> Enum.map(&generate_param_sets/1)
    |> refresh_table_schema(table)
    |> refresh_ecto_schema(table)
    |> Task.async_stream(fn params -> persist(params, table) end)
    |> Stream.run()

    data
  end

  defp refresh_table_schema(params_sets, table) do
    columns = params_sets |> Enum.reduce([], &field_names/2) |> Enum.uniq()

    Ecto.Adapters.SQL.query!(
      Repo,
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
    |> Enum.map(fn col -> "#{col} varchar(#{CoercedString.max_length()})" end)
    |> Enum.join(",")
    |> (&Repo.query!("CREATE TABLE #{table} (#{&1});")).()
  end

  defp create_columns(_table, []), do: :ok

  defp create_columns(table, columns) do
    columns
    |> Enum.map(fn col -> "ADD COLUMN #{col} varchar(#{CoercedString.max_length()})" end)
    |> Enum.join(",")
    |> (&Repo.query!("ALTER TABLE #{table} #{&1};")).()
  end

  # TODO notes
  # current: recreate module entirely on the fly
  # option: create modules one time, update schema on the fly? gets rid of warnings
  # Module.eval_quoted ^
  # generates ecto model for dynamic tables. example: sample_table -> Octopus.SampleTable
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

  defp generate_param_sets(data, prefixes \\ []) when is_map(data) do
    data
    |> Map.keys()
    |> Enum.reduce(%{}, fn field, params ->
      cond do
        is_map(data[field]) ->
          generate_param_sets(data[field], prefixes ++ [field])
          |> Map.merge(params)

        is_list(data[field]) && data[field] |> List.first() |> is_binary() ->
          data[field]
          |> Enum.join(", ")
          |> (&Map.put(%{}, field, &1)).()
          |> generate_param_sets(prefixes)
          |> Map.merge(params)

        is_list(data[field]) ->
          data[field]
          |> Enum.with_index()
          |> Enum.flat_map(fn {item, idx} ->
            generate_param_sets(item, prefixes ++ [field, idx])
          end)
          |> Enum.reduce(params, fn {col, value}, acc -> Map.put(acc, col, value) end)

        true ->
          case prefixes do
            [] -> field
            [_ | _] -> "#{Enum.join(prefixes, "_")}_#{field}"
          end
          |> String.replace(~r/[\(\)\/]/, "")
          |> String.replace("#", "number")
          |> Recase.to_snake()
          |> String.to_atom()
          |> (&Map.put(params, &1, data[field])).()
      end
    end)
  end
end
