ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Octopus.Repo, :manual)
Mox.defmock(Octopus.Client.DelightedMock, for: Octopus.Client.DelightedClient)
Mox.defmock(Octopus.Sink.WarehouseMock, for: Octopus.Sink)
