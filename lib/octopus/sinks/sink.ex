defmodule Octopus.Sink do
  @callback store(String.t(), list(map())) :: list(map())
end
