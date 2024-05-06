defmodule Armychess.Db.Game do
  use Ecto.Schema
  import Ecto.Changeset

  schema "games" do
    field :status, :string
    field :winner, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:winner, :status])
    |> validate_required([:winner, :status])
  end
end
