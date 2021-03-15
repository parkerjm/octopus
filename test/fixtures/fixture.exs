defmodule Fixture do
  def read(name) do
    name |> fq_path |> File.read!()
  end

  def stream(name) do
    name |> fq_path |> File.stream!()
  end

  def exec(name) do
    name |> fq_path |> Code.eval_file() |> elem(0)
  end

  def json(name) do
    name |> read |> Jason.decode!()
  end

  def fq_path(name) do
    Path.join(__DIR__, name)
  end
end
