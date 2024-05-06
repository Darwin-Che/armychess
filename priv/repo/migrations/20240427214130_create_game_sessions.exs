defmodule Armychess.Repo.Migrations.CreateGameSessions do
  use Ecto.Migration

  def change do
    create table(:game_sessions) do
      add :game_id, :integer
      add :player_side, :text
      add :session, :text

      add :lock_version, :integer, default: 1

      timestamps(type: :utc_datetime)
    end
  end
end
