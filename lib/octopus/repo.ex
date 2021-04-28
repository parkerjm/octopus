defmodule Octopus.Repo do
  use Ecto.Repo,
    otp_app: :octopus,
    adapter: Ecto.Adapters.Postgres

  @readonly_repos []

  for repo <- @readonly_repos do
    defmodule repo do
      use Ecto.Repo,
        otp_app: :octopus,
        adapter: Ecto.Adapters.Postgres,
        read_only: true
    end
  end
end
