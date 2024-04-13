defmodule Armychess.GamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Armychess.Games` context.
  """

  @doc """
  Generate a game.
  """
  def game_fixture(attrs \\ %{}) do
    {:ok, game} =
      attrs
      |> Enum.into(%{
        status: "some status",
        winner: "some winner"
      })
      |> Armychess.Games.create_game()

    game
  end
end
