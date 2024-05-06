defmodule ArmychessWeb.GameLive.Play do
  use ArmychessWeb, :live_view

  alias ArmychessWeb.GameLive.Models.Game
  alias ArmychessWeb.GameLive.Models.Piece
  alias ArmychessWeb.GameLive.Models.Slot
  alias ArmychessWeb.GameLive.Functions.Action
  alias ArmychessWeb.GameLive.Functions.Mount

  require Logger

  def mount(params, _session, socket) do
    game_id = params["game_id"]
    player_side = params["player_side"]

    socket = socket
    |> assign(:game_id, game_id)
    |> assign(:player_side, player_side)
    |> assign(:loading, true)

    if connected?(socket) do
      {:ok, game_init} = Armychess.Server.PlaySession.join(game_id, player_side)

      socket = socket
      |> Action.mount_game(game_init)
      |> Mount.mount_stream_pieces()
      |> Mount.mount_stream_slots()
      |> Mount.mount_selected()
      |> assign(:loading, false)

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  def handle_info({:disconnected}, socket) do
    # {:noreply, push_navigate(socket, to: "/games/#{socket.assigns.game_id}")}
    {:noreply, socket |> assign(:loading, true)}
  end

  def handle_event("click-chess", %{"id" => piece} = value, socket) do
    Logger.info("handle_event click-chess #{piece}")

    socket = cond do
      # case 0: Fail
      !Piece.is_valid_piece(piece) ->
        Logger.error("Unhandled Event: click-chess #{piece}; Reason: Invalid clicked_piece.")
        socket
      # case 1: selected a reachable enemy piece, start an attack
      socket.assigns.selected != nil && Piece.is_enemy_piece(piece) ->
        socket
        |> Action.attack(socket.assigns.selected, piece)
      # case 2: selected a selected piece, deselect it
      socket.assigns.selected == piece ->
        socket
        |> Action.deselect_piece()
      # case 3: selected a owned piece, assign it to selected
      Piece.is_owned_piece(piece) ->
        socket
        |> Action.select_piece(piece)
      # Unexpected Cases
      true ->
        Logger.error("Unhandled Event: click-chess #{piece}; Reason: Unexpected case.")
        socket
    end
    |> Action.updated()

    {:noreply, socket}
  end

  def handle_event("click-slot", %{"id" => slot_id} = value, socket) do
    Logger.info("handle_event click-slot #{slot_id}")
    socket = cond do
      # case 0: Fail
      !Slot.is_valid_slot(slot_id) ->
        Logger.error("Unhandled Event: click-slot #{slot_id}; Reason: Invalid slot.")
        socket
      # case 1: There is a selected piece
      socket.assigns.selected != nil
          and Game.get_selectable_targets(socket.assigns.game, socket.assigns.selected) |> elem(1) |> Enum.member?(slot_id) ->
        socket
        |> Action.reach(socket.assigns.selected, slot_id)
      # Unexpected Cases
      true ->
        Logger.error("Unhandled Event: click-slot #{slot_id}; Reason: Unexpected case.")
        socket
    end
    |> Action.updated()

    {:noreply, socket}
  end

end
