defmodule RuberDuckDebug.Repo do
  use Ecto.Repo,
    otp_app: :ruber_duck_debug,
    adapter: Ecto.Adapters.Postgres
end
