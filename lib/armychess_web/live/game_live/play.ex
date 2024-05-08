defmodule ArmychessWeb.GameLive.Play do
  use ArmychessWeb, :live_view
  import Phoenix.LiveView, only: [connected?: 1, stream: 3, stream_insert: 3]

  alias ArmychessWeb.GameLive.Models.Game
  alias ArmychessWeb.GameLive.Models.Piece
  alias ArmychessWeb.GameLive.Models.Slot
  alias ArmychessWeb.GameLive.Functions.Action
  alias ArmychessWeb.GameLive.Functions.Mount

  require Logger

  @moduledoc """
  The socket stores the following information

  - game_id
  - player_side
  - slot_map (update via slot_stream)
    Defines which slot is clickable or has the highlight border

  - game_phase
    :connecting, :placing, :wait_placing, :moving, :wait_moving, :game_win, :game_lose
  - piece_map (update via piece_stream)
    Defines the pieces on the board, including slots and status
  - board_map
    A lookup map to faciliate finding piece on a particular slot

  - selected
    A temporary to store the last selected element
    Value can be `nil`, `{:piece, "piece_xxx"}`

  - stream_changes
    A temporary to store the changed elements, so that we don't stream_insert one object multiple times
  """

  def mount(params, _session, socket) do
    game_id = params["game_id"]
    player_side = params["player_side"]

    socket = socket
    |> assign(:game_id, game_id)
    |> assign(:player_side, player_side)
    |> Action.init_slot()
    |> assign(:game_phase, :connecting)
    |> assign(:piece_map, %{})
    |> stream(:piece_stream, [])
    |> assign(:board_map, %{})
    |> assign(:selected, nil)
    |> assign(:stream_changes, [])

    if connected?(socket) do
      {:ok, session_state} = Armychess.Server.PlaySession.join(game_id, player_side)

      socket = socket
      |> Action.init_game_state(session_state)
      |> Action.update_clickable()
      |> stream_changes()

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @spec handle_info(any(), any()) :: {:noreply, any()}
  def handle_info([:player_ready, player_side], socket) do
    Logger.debug("handle_info player_ready(#{player_side})")

    socket =
      if player_side == socket.assigns.player_side do
        socket
      else
        session_state = Armychess.Server.PlaySession.session_state(socket.assigns.game_id, player_side)

        socket
        |> Action.init_enemy_pieces(session_state)
      end

    {:noreply, socket}
  end

  def handle_info([:player_reach, player_side, from_slot, to_slot], socket) do
    Logger.debug("handle_info(#{socket.assigns.player_side}) player_reach(#{player_side}) #{from_slot} -> #{to_slot}")

    {:ok, session_state} = Armychess.Server.PlaySession.get_state(socket.assigns.game_id)

    socket =
      socket
      |> Action.handle_reach(from_slot, to_slot)
      |> Action.assign_game_phase(session_state)
      |> Action.update_marks(%{from_slot => "selected", to_slot => "target"})
      |> Action.update_clickable()
      |> stream_changes()

    {:noreply, socket}
  end

  def handle_info([:player_attack, player_side, from_slot, to_slot, attack_result], socket) do
    Logger.debug("handle_info(#{socket.assigns.player_side}) player_attack(#{player_side}) #{from_slot} -> #{to_slot} = #{attack_result}")

    {:ok, session_state} = Armychess.Server.PlaySession.get_state(socket.assigns.game_id)

    socket =
      socket
      |> Action.handle_attack(from_slot, to_slot, attack_result)
      |> Action.assign_game_phase(session_state)
      |> Action.update_marks(%{from_slot => "selected", to_slot => "target"})
      |> Action.update_clickable()
      |> stream_changes()

    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    Logger.info(inspect(msg))
    {:noreply, socket}
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
    |> Action.update_clickable()
    |> stream_changes()

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
          and Action.get_selectable(socket, socket.assigns.selected) |> elem(1) |> Enum.member?(slot_id) ->
        socket
        |> Action.reach(socket.assigns.selected, slot_id)
      # Unexpected Cases
      true ->
        Logger.error("Unhandled Event: click-slot #{slot_id}; Reason: Unexpected case.")
        socket
    end
    |> Action.update_clickable()
    |> stream_changes()

    {:noreply, socket}
  end

  def stream_changes(socket) do
    socket.assigns.stream_changes
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.reduce(socket, fn id, socket ->
      cond do
        Piece.is_valid_piece(id) ->
          socket |> stream_insert(:piece_stream, Action.get_piece(socket, id))
        Slot.is_valid_slot(id) ->
          socket |> stream_insert(:slot_stream, Action.get_slot(socket, id))
        true ->
          Logger.error("Cannot stream changes #{id}")
          socket
      end
    end)
    |> assign(:stream_changes, [])
  end

end
