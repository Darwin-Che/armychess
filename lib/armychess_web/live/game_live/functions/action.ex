defmodule ArmychessWeb.GameLive.Functions.Action do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [stream_insert: 3]

  alias ArmychessWeb.GameLive.Models.Game
  alias ArmychessWeb.GameLive.Models.Slot
  alias ArmychessWeb.GameLive.Models.Piece

  alias Armychess.Server.PlaySession

  require Logger


  def ready(socket) do
    # place_list [{piece, slot}]
    place_list =
      socket.assigns.game.piece_map
      |> Enum.filter(fn {id, _} -> Piece.is_owned_piece(id) end)
      |> Enum.map(fn {_, p} -> {p.display, p.slot} end)

    case PlaySession.ready(socket.assigns.game_id, place_list) do
      :ok -> socket
      :rejected -> socket |> assign(:loading, true)
    end
  end

  def select_piece(socket, piece) do
    game = socket.assigns.game

    {target_pieces, target_slots} = Game.get_selectable_targets(game, piece)

    game =
      game
      |> Game.reset_slots()
      # |> Game.reset_pieces_enabled()
      |> Game.set_slots_enabled(target_slots)
      |> Game.set_pieces_mark(target_pieces, "target")
      |> Game.set_pieces(target_pieces, enabled: true)
      |> Game.set_pieces_mark([piece], "selected")

    socket
    |> assign(:selected, piece)
    |> assign(:game, game)
  end

  def deselect_piece(socket) do
    game = socket.assigns.game
    piece = socket.assigns.selected

    game =
      game
      |> Game.reset_slots()
      # |> Game.reset_pieces_enabled()

    socket
    |> assign(:selected, nil)
    |> assign(:game, game)
  end

  def attack(socket, from_piece, to_piece) do
    play_session = socket.assigns.play_session
    game = socket.assigns.game

    from_piece = Game.get_piece(game, from_piece)
    to_piece = Game.get_piece(game, to_piece)

    game = game
    |> Game.reset_slots()
    |> Game.set_pieces_mark([from_piece.id], "selected")
    |> Game.set_pieces_mark([to_piece.id], "target")

    game = case PlaySession.attack(play_session, from_piece.display, from_piece.slot, to_piece.slot) do
      :rejected ->
        game

      :win ->
        game
        |> Game.set_piece_move(to_piece.id, nil)
        |> Game.set_piece_move(from_piece.id, to_piece.slot)

      :lose ->
        game
        |> Game.set_piece_move(from_piece.id, nil)

      :draw ->
        game
        |> Game.set_piece_move(from_piece.id, nil)
        |> Game.set_piece_move(to_piece.id, nil)
    end

    socket
    |> assign(:selected, nil)
    |> assign(:game, game)
  end

  def reach(socket, piece, to_slot) do
    play_session = socket.assigns.play_session
    game = socket.assigns.game
    piece = Game.get_piece(game, piece)

    game = game
    |> Game.reset_slots()
    |> Game.set_slots_mark([piece.slot], "selected")
    |> Game.set_slots_mark([to_slot], "target")

    game = case PlaySession.reach(play_session, piece.display, piece.slot, to_slot) do
      :rejected ->
        game

      :ok ->
        Logger.debug "HERE #{piece.id} #{to_slot}"
        game
        |> Game.set_piece_move(piece.id, to_slot)
    end

    socket
    |> assign(:selected, nil)
    |> assign(:game, game)
  end

  # Called at the end of the handler
  def updated(socket) do
    game = socket.assigns.game

    update_list_piece =
      socket.assigns.game.update_list_piece
      |> List.flatten()
      |> Enum.uniq()
      # |> IO.inspect

    socket =
      Game.get_pieces(game, update_list_piece)
      |> List.foldl(socket, fn piece, socket ->
        stream_insert(socket, :pieces, piece)
      end)

    update_list_slot =
      socket.assigns.game.update_list_slot
      |> List.flatten()
      |> Enum.uniq()
      # |> IO.inspect

    socket =
      Game.get_slots(game, update_list_slot)
      |> List.foldl(socket, fn slot, socket ->
        stream_insert(socket, :slots, slot)
      end)

    game =
      game
      |> Map.put(:update_list_piece, [])
      |> Map.put(:update_list_slot, [])

    socket
    |> assign(:game, game)
  end
end
