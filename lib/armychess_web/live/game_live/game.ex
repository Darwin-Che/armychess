defmodule ArmychessWeb.GameLive.Game do
  use ArmychessWeb, :live_view

  alias Armychess.Db
  alias Armychess.Repo

  def mount(params, _session, socket) do
    game_id = params["game_id"]

    game_sessions =
      Repo.all(Db.GameSession, game_id: game_id)
      |> Map.new(fn s -> {s.player_side, s} end)

    socket = socket
    |> assign(:game_id, game_id)
    |> assign(:player_1_free, game_sessions["1"] |> player_free())
    |> assign(:player_2_free, game_sessions["2"] |> player_free())

    # :timer.send_interval(5000, :tick)

    {:ok, socket}
  end

  def handle_info(:tick, socket) do
    game_sessions =
      Repo.all(Db.GameSession, game_id: socket.assigns.game_id)
      |> Map.new(fn s -> {s.player_side, s} end)

    socket = socket
    |> assign(:player_1_free, game_sessions["1"] |> player_free())
    |> assign(:player_2_free, game_sessions["2"] |> player_free())

    {:noreply, socket}
  end

  defp player_free(nil) do
    true
  end
  defp player_free(game_session) do
    game_session.session == nil
  end
end
