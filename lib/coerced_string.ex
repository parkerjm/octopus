defmodule CoercedString do
  use Ecto.Type

  @max_column_length 500

  def max_length, do: @max_column_length
  def type, do: :string
  def load(val), do: {:ok, val}
  def dump(val), do: {:ok, val}
  def cast(nil), do: nil

  ##
  # transformations:
  # 1) convert value to string
  # 2) remove all whitespace chars with spaces as these can be inserted as two chars (i.e. "\r") in the database
  # 3) trim string to max length of 500
  def cast(val) do
    {:ok,
     val
     |> to_string
     |> String.replace(~r/\s+/, " ")
     |> String.slice(0, max_length())}
  end
end
