defmodule Octopus.Client.DelightedClient do
  @callback get_survey_responses(number(), number()) :: list(map())
end
