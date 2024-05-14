defmodule ArmychessWeb.GameLive.Index do
  use ArmychessWeb, :live_view

  import Ecto.Query

  alias Armychess.Db
  alias Armychess.Repo

  require Logger

  def mount(_params, _session, socket) do
    query =
      from g in Db.Game,
      order_by: [desc: :inserted_at],
      limit: 15

    recent_games = Repo.all(query)

    socket = socket
      |> assign(:games, recent_games)
      |> assign(:create_game_id, nil)

    {:ok, socket}
  end

  def handle_event("click-create-game", _value, socket) do
    Logger.info("click-create-game")

    # Insert a game
    game = %Db.Game{} |> Repo.insert!()

    %Db.GameSession{game_id: game.id, player_side: "1"} |> Repo.insert!()
    %Db.GameSession{game_id: game.id, player_side: "2"} |> Repo.insert!()

    {:noreply, push_navigate(socket, to: "/games/#{game.id}")}
  end
end
