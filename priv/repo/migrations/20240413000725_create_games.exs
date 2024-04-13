defmodule Armychess.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :winner, :text
      add :status, :text

      timestamps(type: :utc_datetime)
    end
  end
end
