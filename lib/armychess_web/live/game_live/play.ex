defmodule ArmychessWeb.GameLive.Play do
  use ArmychessWeb, :live_view

  import Phoenix.LiveView,
    only: [
      connected?: 1,
      stream: 3,
      stream_insert: 3,
      stream_delete_by_dom_id: 3,
      push_navigate: 2
    ]

  # import ArmychessWeb.Components.Placebtn, only: [placebtn: 1]

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

  - placebtn_cnt
    %{"President" => 1}
  """

  def mount(params, _session, socket) do
    game_id = params["game_id"]
    player_side = params["player_side"]

    socket =
      socket
      |> assign(:game_id, game_id)
      |> assign(:player_side, player_side)
      |> Action.init_slot()
      |> assign(:game_phase, :connecting)
      |> assign(:piece_map, %{})
      |> stream(:piece_stream, [])
      |> assign(:board_map, %{})
      |> assign(:selected, nil)
      |> assign(:stream_changes, [])
      |> assign(:placebtn_selected, nil)
      |> assign(:placebtn_cnt, Armychess.Entity.Piece.available_list() |> Map.new())

    if connected?(socket) do
      socket =
        case Armychess.Server.PlaySession.join(game_id, player_side) do
          {:ok, session_state} ->
            socket
            |> Action.init_game_state(session_state)
            |> Action.update_clickable()
            |> stream_changes()

          _ ->
            socket
            |> push_navigate(to: "/games/#{game_id}")
        end

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @spec handle_info(any(), any()) :: {:noreply, any()}
  def handle_info([:player_ready, player_side], socket) do
    Logger.debug("handle_info player_ready(#{player_side})")

    {:ok, session_state} = Armychess.Server.PlaySession.get_state(socket.assigns.game_id)

    socket =
      if player_side == socket.assigns.player_side do
        socket
      else
        socket
        |> Action.init_enemy_pieces(session_state)
      end
      |> Action.assign_game_phase(session_state)
      |> Action.update_clickable()
      |> stream_changes()

    {:noreply, socket}
  end

  def handle_info([:player_reach, player_side, from_slot, to_slot], socket) do
    Logger.debug(
      "handle_info(#{socket.assigns.player_side}) player_reach(#{player_side}) #{from_slot} -> #{to_slot}"
    )

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
    Logger.debug(
      "handle_info(#{socket.assigns.player_side}) player_attack(#{player_side}) #{from_slot} -> #{to_slot} = #{attack_result}"
    )

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

  def handle_event("click-chess", %{"id" => piece_id} = value, socket) do
    Logger.info("handle_event click-chess #{piece_id}")

    socket =
      cond do
        # case 0: Fail
        !Piece.is_valid_piece(piece_id) ->
          Logger.error("Unhandled Event: click-chess #{piece_id}; Reason: Invalid clicked_piece.")
          socket

        # case 1: selected a reachable enemy piece, start an attack
        socket.assigns.game_phase == :moving and socket.assigns.selected != nil &&
            Piece.is_enemy_piece(piece_id) ->
          socket
          |> Action.attack(socket.assigns.selected, piece_id)

        # case 2: selected a selected piece, deselect it
        socket.assigns.game_phase == :moving and socket.assigns.selected == piece_id ->
          socket
          |> Action.deselect_piece()

        # case 3: selected a owned piece, assign it to selected
        socket.assigns.game_phase == :moving and Piece.is_owned_piece(piece_id) ->
          socket
          |> Action.select_piece(piece_id)

        # case 4: when placing, clicking on an existing piece means unplace it
        socket.assigns.game_phase == :placing ->
          socket
          |> Action.unplace(piece_id)

        # Unexpected Cases
        true ->
          Logger.error("Unhandled Event: click-chess #{piece_id}; Reason: Unexpected case.")
          socket
      end
      |> Action.update_clickable()
      |> stream_changes()

    {:noreply, socket}
  end

  def handle_event("click-slot", %{"id" => slot_id} = value, socket) do
    Logger.info("handle_event click-slot #{slot_id}")

    socket =
      cond do
        # case 0: Fail
        !Slot.is_valid_slot(slot_id) ->
          Logger.error("Unhandled Event: click-slot #{slot_id}; Reason: Invalid slot.")
          socket

        # case 1: There is a selected piece
        socket.assigns.game_phase == :moving and socket.assigns.selected != nil and
            Action.get_reachable(socket, socket.assigns.selected)
            |> elem(1)
            |> Enum.member?(slot_id) ->
          socket
          |> Action.reach(socket.assigns.selected, slot_id)

        # case 2: Placing on this slot
        socket.assigns.game_phase == :placing and socket.assigns.placebtn_selected != nil and
            Action.get_placeable(socket, socket.assigns.placebtn_selected)
            |> Enum.member?(slot_id) ->
          socket
          |> Action.place(socket.assigns.placebtn_selected, slot_id)

        # Unexpected Cases
        true ->
          Logger.error("Unhandled Event: click-slot #{slot_id}; Reason: Unexpected case.")
          socket
      end
      |> Action.update_clickable()
      |> stream_changes()

    {:noreply, socket}
  end

  def handle_event("click-placebtn", %{"id" => p} = value, socket) do
    Logger.info("handle_event click-placebtn #{p}")

    socket =
      cond do
        # case 1: Unselect the selected
        socket.assigns.game_phase == :placing and socket.assigns.placebtn_selected == p ->
          socket
          |> assign(:placebtn_selected, nil)

        # case 2: Selected the clicked
        socket.assigns.game_phase == :placing and socket.assigns.placebtn_cnt[p] > 0 ->
          socket
          |> assign(:placebtn_selected, p)

        true ->
          Logger.error("Unhandled Event: click-placebtn #{p}; Reason: Unexpected case.")
          socket
      end
      |> Action.update_clickable()
      |> stream_changes()

    {:noreply, socket}
  end

  def handle_event("click-placebtn-ready", _, socket) do
    Logger.info("handle_event click-placebtn-ready")

    socket =
      cond do
        # check if every piece is placed
        socket.assigns.game_phase == :placing and
            socket.assigns.placebtn_cnt |> Map.values() |> Enum.all?(&(&1 == 0)) ->
          socket
          |> assign(:placebtn_selected, nil)
          |> Action.ready(
            socket.assigns.piece_map
            |> Enum.filter(fn {piece_id, _} -> Piece.is_owned_piece(piece_id) end)
            |> Map.new(fn {_, p} -> {p.slot, p.display} end)
          )

        true ->
          Logger.error(
            "Unhandled Event: click-placebtn-ready; Reason: Not all pieces are placed."
          )

          socket
      end
      |> Action.update_clickable()
      |> stream_changes()

    {:noreply, socket}
  end

  def handle_event("click-placebtn-preset", _, socket) do
    Logger.info("handle_event click-placebtn-ready")

    socket =
      cond do
        # load the rest of pieces randomly on to the board
        socket.assigns.game_phase == :placing ->
          socket
          |> Action.place_preset()

        true ->
          Logger.error(
            "Unhandled Event: click-placebtn-ready; Reason: Not all pieces are placed."
          )

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
          piece = Action.get_piece(socket, id)

          if piece do
            socket |> stream_insert(:piece_stream, piece)
          else
            socket |> stream_delete_by_dom_id(:piece_stream, id)
          end

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
