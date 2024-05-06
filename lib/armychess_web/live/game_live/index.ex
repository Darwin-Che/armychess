defmodule ArmychessWeb.GameLive.Index do
  use ArmychessWeb, :live_view

  alias Armychess.Db.Game
  alias Armychess.Db.GameSession
  alias Armychess.Repo

  require Logger

  def mount(_params, _session, socket) do
    socket = socket
      |> assign(:games, Repo.all(Game))
      |> assign(:create_game_id, nil)

    {:ok, socket}
  end

  def handle_event("click-create-game", _value, socket) do
    Logger.info("click-create-game")

    # Insert a game
    game = %Game{} |> Repo.insert!()

    %GameSession{game_id: game.id, player_side: "player1"} |> Repo.insert!()
    %GameSession{game_id: game.id, player_side: "player2"} |> Repo.insert!()

    socket =
      socket
      |> assign(:game_id, game.id)

    {:noreply, socket}
  end
end
