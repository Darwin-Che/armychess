defmodule ArmychessWeb.GameLive.Functions.Mount do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [stream: 3]

  alias ArmychessWeb.GameLive.Models.Slot
  alias ArmychessWeb.GameLive.Models.Game

  def mount_game(socket, game_id) do
    socket
    |> assign(:game, Game.load(game_id))
  end

  def mount_stream_pieces(socket) do
    socket
    |> stream(:pieces, Game.from_socket(socket) |> Game.all_pieces())
  end

  def mount_stream_slots(socket) do
    socket
    |> stream(:slots, Game.from_socket(socket) |> Game.all_slots())
  end

  def mount_selected(socket) do
    socket
    |> assign(:selected, nil)
  end

  def mount_server(socket) do
    socket
    |> assign(:server,
      Armychess.Server.Play.new(
        socket.assigns.game_id,
        socket.assigns.host_id
      ))
  end
  # defp wrap(l, key) when is_list(l) do
  #   Enum.map(l, fn x -> wrap(x, key) end)
  # end

  # defp wrap(val, key) do
  #   %{key => val}
  # end
end
