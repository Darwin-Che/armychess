defmodule Armychess.Db.GameSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_sessions" do
    field :game_id, :integer
    field :player_side, :string

    field :session, :string

    field :lock_version, :integer, default: 1

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(struct, :update, params \\ %{}) do
    struct
    |> Ecto.Changeset.cast(params, [:session])
    |> Ecto.Changeset.optimistic_lock(:lock_version)
  end
end
