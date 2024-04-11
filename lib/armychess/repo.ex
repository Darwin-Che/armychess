defmodule Armychess.Repo do
  use Ecto.Repo,
    otp_app: :armychess,
    adapter: Ecto.Adapters.Postgres
end
