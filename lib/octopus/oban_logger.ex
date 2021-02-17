defmodule Octopus.ObanLogger do
  require Logger

  def handle_event([:oban, :job, :start], measure, meta, _) do
    Logger.warn("[Oban] :started #{meta.worker} at #{measure.system_time}")
  end

  def handle_event([:oban, :job, :failure], _, meta, _) do
    Logger.error(
      "[Oban] Failure: #{meta.worker} encountered error #{meta[:error][:postgres][:message]}"
    )
  end

  def handle_event([:oban, :job, event], measure, meta, _) do
    Logger.warn("[Oban] #{event} #{meta.worker} ran in #{measure.duration}")
  end
end
