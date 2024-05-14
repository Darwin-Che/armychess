defmodule Armychess.Db.GameSession do
  use Ecto.Schema
  import Ecto.Changeset

  import Ecto.Query

  alias Armychess.Db
  alias Armychess.Repo

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

  def upsert(game_id, player_side, session) do
    game_id = if is_binary(game_id) do
      game_id |> Integer.parse() |> elem(0)
    else
      game_id
    end

    if s = Repo.get_by(__MODULE__, [game_id: game_id, player_side: player_side]) do
      # exist record
      Db.GameSession.changeset(s, :update, %{session: session}) |> Repo.update!()
    else
      # record not exist
      %Db.GameSession{game_id: game_id, player_side: player_side} |> Repo.insert!()
    end
  end
end
