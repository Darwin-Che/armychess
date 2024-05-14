defmodule ArmychessWeb.GameLive.Functions.Action do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [stream: 3]

  alias ArmychessWeb.GameLive.Models.Game
  alias ArmychessWeb.GameLive.Models.Slot
  alias ArmychessWeb.GameLive.Models.Piece

  alias Armychess.Server.PlaySession

  require Logger

  def init_slot(socket) do
    slots =
      for s <- [0, 9], c <- 1..5, r <- 1..6 do
        %Slot{
          id: "slot_#{s}#{r}#{c}"
        }
      end

    slot_map = Map.new(slots, fn slot -> {slot.id, slot} end)

    socket
    |> assign(:slot_map, slot_map)
    |> stream(:slot_stream, slots)
  end

  @doc """
  The function reads the current state in the socket, compare `game_state` to get diff.
  It updates the socket with `game_phase`, `piece_map`, `piece_stream`, `board_map`
  ```
  session_state = %{
    phase: , # {:ready, []}, {:move, "1"}, {:end, "1"}
    owned_pieces: %{"slot_0xx" => "President"},
    enemy_pieces: ["slot_9xx"],
  }
  ```
  """
  def init_game_state(socket, session_state) do
    socket =
      case socket.assigns.game_phase do
        :connecting ->
          socket
          |> init_owned_pieces(session_state)
          |> init_enemy_pieces(session_state)

        _ ->
          # TODO: Verify the board from session_state with the current state
          socket
      end

    socket
    |> assign(:game_phase, translate_game_phase(session_state.phase, socket.assigns.player_side))
  end

  # Session Game State: {:ready, []}, {:move, "1"}, {:end, "1"}
  # Action Game State: :connecting, :placing, :wait_placing, :moving, :wait_moving, :game_win, :game_lose
  defp translate_game_phase(session_phase, player_side) do
    case session_phase do
      {:ready, ready_list} ->
        if player_side not in ready_list do
          :placing
        else
          :wait_placing
        end

      {:move, s} when player_side == s ->
        :moving

      {:move, s} when player_side != s ->
        :wait_moving

      {:end, s} when player_side == s ->
        :game_win

      {:end, s} when player_side != s ->
        :game_lose
    end
  end

  def assign_game_phase(socket, session) do
    socket
    |> assign(:game_phase, translate_game_phase(session.phase, socket.assigns.player_side))
  end

  def init_owned_pieces(socket, session_state) do
    if Enum.any?(socket.assigns.piece_map, fn {id, _} -> Piece.is_owned_piece(id) end) do
      Logger.error("Cannot init_owned_pieces : already initialized")
      # TODO: exit
    end

    piece_map_owned =
      Enum.with_index(session_state.owned_pieces)
      |> Map.new(fn {{slot, display}, idx} ->
        id = "piece_0#{idx |> Integer.to_string() |> String.pad_leading(2, "0")}"
        {id, %Piece{id: id, slot: slot, display: display}}
      end)

    socket =
      Enum.reduce(piece_map_owned, socket, fn {_, piece}, socket ->
        set_stream_changes(socket, piece.id)
      end)

    piece_map = Map.merge(socket.assigns.piece_map, piece_map_owned)

    board_map =
      Map.merge(
        socket.assigns.board_map,
        Map.new(piece_map_owned, fn {_, piece} -> {piece.slot, piece.id} end)
      )

    socket
    |> assign(:piece_map, piece_map)
    |> assign(:board_map, board_map)
  end

  def init_enemy_pieces(socket, session_state) do
    if Enum.any?(socket.assigns.piece_map, fn {id, _} -> Piece.is_enemy_piece(id) end) do
      Logger.error("Cannot init_enemy_pieces : already initialized")
      # TODO: exit
    end

    piece_map_enemy =
      Enum.with_index(session_state.enemy_pieces)
      |> Map.new(fn {slot, idx} ->
        id = "piece_9#{idx |> Integer.to_string() |> String.pad_leading(2, "0")}"
        {id, %Piece{id: id, slot: slot, display: "Empty"}}
      end)

    socket =
      Enum.reduce(piece_map_enemy, socket, fn {_, piece}, socket ->
        set_stream_changes(socket, piece.id)
      end)

    piece_map = Map.merge(socket.assigns.piece_map, piece_map_enemy)

    board_map =
      Map.merge(
        socket.assigns.board_map,
        Map.new(piece_map_enemy, fn {_, piece} -> {piece.slot, piece.id} end)
      )

    socket
    |> assign(:piece_map, piece_map)
    |> assign(:board_map, board_map)
  end

  def ready(socket, place_map \\ nil) do
    place_map = place_map || default_place()

    case PlaySession.ready(socket.assigns.game_id, place_map) do
      {:ok} -> socket
      {:rejected, err} -> reject(socket)
    end
  end

  def place(socket, p, slot_id) do
    if socket.assigns.placebtn_cnt[p] > 0 do
      piece_id = slot_id |> String.replace("slot_", "piece_")
      piece = %Piece{id: piece_id, display: p, slot: slot_id}
      board_map = Map.put(socket.assigns.board_map, slot_id, piece_id)

      socket =
        socket
        |> insert_piece(piece)
        |> assign(:board_map, board_map)
        |> assign(:placebtn_cnt, socket.assigns.placebtn_cnt |> update_in([p], &(&1 - 1)))

      if socket.assigns.placebtn_cnt[p] == 0 do
        socket
        |> assign(:placebtn_selected, nil)
      else
        socket
      end
    else
      socket
    end
  end

  def place_preset(socket) do
    pieces =
      Armychess.Entity.Piece.available_list()
      |> Enum.map(&(&1 |> elem(0)))
      |> Enum.map(&List.duplicate(&1, socket.assigns.placebtn_cnt[&1] || 0))
      |> List.flatten()

    Enum.reduce(pieces, socket, fn p, socket ->
      placeable_slots = get_placeable(socket, p)

      if placeable_slots == [] do
        socket
      else
        socket
        |> place(p, Enum.random(placeable_slots))
      end
    end)
  end

  def unplace(socket, piece_id) do
    piece = get_piece(socket, piece_id)

    board_map = Map.delete(socket.assigns.board_map, piece.slot)

    socket
    |> delete_piece(piece_id)
    |> assign(:board_map, board_map)
    |> assign(:placebtn_cnt, socket.assigns.placebtn_cnt |> update_in([piece.display], &(&1 + 1)))
  end

  def reject(socket) do
    # TODO: Add message into the chat box
    socket
  end

  defp default_place() do
    %{
      "slot_011" => "President",
      "slot_012" => "General",
      "slot_013" => "Colonel",
      "slot_014" => "Colonel",
      "slot_015" => "Major",
      "slot_021" => "Major",
      # "slot_022" => "Captain",
      "slot_023" => "Captain",
      # "slot_024" => "Lieutenant",
      "slot_025" => "Captain",
      "slot_031" => "Lieutenant",
      "slot_032" => "Lieutenant",
      # "slot_033" => "Corporal",
      "slot_034" => "Sergeant",
      "slot_035" => "Sergeant",
      "slot_041" => "Sergeant",
      # "slot_042" => "Landmine",
      "slot_043" => "Corporal",
      # "slot_044" => "Landmine",
      "slot_045" => "Corporal",
      "slot_051" => "Corporal",
      "slot_052" => "Sapper",
      "slot_053" => "Sapper",
      "slot_054" => "Sapper",
      "slot_055" => "Landmine",
      "slot_061" => "Landmine",
      "slot_062" => "Landmine",
      "slot_063" => "Bomb",
      "slot_064" => "HQ",
      "slot_065" => "Bomb"
    }
  end

  def select_piece(socket, piece_id) do
    {attackable, selectable} = get_reachable(socket, piece_id)

    marks =
      %{piece_id => "selected"}
      |> Map.merge(Map.new(attackable, fn p -> {p, "target"} end))

    socket
    |> assign(:selected, piece_id)
    |> update_marks(marks)
  end

  def deselect_piece(socket) do
    socket
    |> assign(:selected, nil)
    |> update_marks(%{})
  end

  def attack(socket, from_piece, to_piece) do
    game_id = socket.assigns.game_id

    from_piece = get_piece(socket, from_piece)
    to_piece = get_piece(socket, to_piece)

    PlaySession.attack(game_id, from_piece.display, from_piece.slot, to_piece.slot)

    marks = %{from_piece.slot => "selected", to_piece.slot => "target"}

    socket
    |> assign(:selected, nil)
    |> update_marks(marks)
  end

  def reach(socket, piece, to_slot) do
    game_id = socket.assigns.game_id

    piece = get_piece(socket, piece)

    PlaySession.reach(game_id, piece.display, piece.slot, to_slot)

    marks = %{piece.slot => "selected", to_slot => "target"}

    socket
    |> assign(:selected, nil)
    |> update_marks(marks)
  end

  def handle_reach(socket, from_slot, to_slot) do
    p = socket.assigns.board_map[from_slot]

    socket
    |> set_piece_move(p, to_slot)
  end

  def handle_attack(socket, from_slot, to_slot, attack_result) do
    from_piece = socket.assigns.board_map[from_slot]
    to_piece = socket.assigns.board_map[to_slot]

    socket =
      case attack_result do
        :win ->
          socket
          |> set_piece_move(to_piece, nil)
          |> set_piece_move(from_piece, to_slot)

        :lose ->
          socket
          |> set_piece_move(from_piece, nil)

        :draw ->
          socket
          |> set_piece_move(from_piece, nil)
          |> set_piece_move(to_piece, nil)
      end

    socket
  end

  # PUBLIC HELPER

  def update_clickable(socket) do
    {clickable_pieces, clickable_slots} =
      case socket.assigns.game_phase do
        :moving ->
          if socket.assigns.selected != nil do
            # owned pieces, reachable slot, attackable pieces are selectable
            {attackable, reachable} = get_reachable(socket, socket.assigns.selected)
            {get_owned_pieces(socket) ++ attackable, reachable}
          else
            # owned pieces are selectable
            {get_owned_pieces(socket), []}
          end

        :placing ->
          clickable_slots =
            if socket.assigns.placebtn_selected != nil do
              get_placeable(socket, socket.assigns.placebtn_selected)
            else
              []
            end

          clickable_pieces = socket.assigns.board_map |> Map.values()
          {clickable_pieces, clickable_slots}

        _ ->
          # everything should be not clickable
          {[], []}
      end

    socket =
      socket.assigns.piece_map
      |> Enum.reduce(socket, fn {id, p}, socket ->
        cond do
          id in clickable_pieces and !p.enabled ->
            # enable p
            socket
            |> set_piece(id, enabled: true)

          id not in clickable_pieces and p.enabled ->
            # disable p
            socket
            |> set_piece(id, enabled: false)

          true ->
            socket
        end
      end)

    socket =
      socket.assigns.slot_map
      |> Enum.reduce(socket, fn {id, s}, socket ->
        cond do
          id in clickable_slots and !s.enabled ->
            # enable p
            socket
            |> set_slot(id, enabled: true)

          id not in clickable_slots and s.enabled ->
            # disable p
            socket
            |> set_slot(id, enabled: false)

          true ->
            socket
        end
      end)
  end

  # marks = %{"slot_xxx" => "mark"}
  def update_marks(socket, marks) do
    # preprocess marks in case keys are pieces
    piece_marks =
      marks
      |> Enum.filter(fn {k, _v} -> Piece.is_valid_piece(k) end)
      |> Enum.map(fn {k, v} -> {get_piece(socket, k).slot, v} end)
      |> Map.new()

    marks = Map.merge(marks, piece_marks)

    socket.assigns.slot_map
    |> Enum.reduce(socket, fn {sid, slot}, socket ->
      if marks[sid] != slot.mark do
        socket
        |> set_slot(sid, mark: marks[sid])
      else
        socket
      end
    end)
  end

  # HELPERS

  defp get_owned_pieces(socket) do
    socket.assigns.piece_map
    |> Enum.filter(fn {id, _} -> Piece.is_owned_piece(id) end)
    |> Enum.map(fn {id, _} -> id end)
  end

  # return {[piece_id], [slot_id]}
  def get_reachable(socket, piece_id) do
    piece = get_piece(socket, piece_id)

    {attackable_list, reachable_list} =
      Armychess.Entity.Slot.get_reachable(
        piece.slot,
        piece.display,
        fn slot_id ->
          socket.assigns.board_map[slot_id]
        end,
        fn piece_id ->
          Piece.is_enemy_piece(piece_id)
        end
      )

    attackable_list =
      attackable_list
      |> Enum.map(fn slot_id ->
        socket.assigns.board_map[slot_id]
      end)

    {attackable_list, reachable_list}
  end

  # return [slot]
  def get_placeable(socket, p) do
    Armychess.Entity.Piece.placeable_slots(p)
    |> Enum.filter(fn s -> socket.assigns.board_map[s] == nil end)
  end

  # HELPER HELPER

  defp set_piece_move(socket, piece, to_slot) do
    p = get_piece(socket, piece)
    from_slot = p.slot

    socket
    |> set_piece(piece, slot: to_slot)
    |> set_board(from_slot, nil)
    |> set_board(to_slot, piece)
  end

  defp set_board(socket, slot, p) do
    new_board =
      if p == nil do
        Map.delete(socket.assigns.board_map, slot)
      else
        Map.put(socket.assigns.board_map, slot, p)
      end

    socket
    |> assign(:board_map, new_board)
  end

  def get_piece(socket, piece) do
    socket.assigns.piece_map[piece]
  end

  defp set_piece(socket, piece, changeset \\ %{}) do
    p = get_piece(socket, piece) |> struct(changeset)
    # Logger.warning("SET PIECE #{piece} #{inspect p} #{inspect changeset}")
    socket
    |> put_in([Access.key(:assigns), Access.key(:piece_map), piece], p)
    |> set_stream_changes(piece)
  end

  defp insert_piece(socket, p) do
    socket
    |> put_in([Access.key(:assigns), Access.key(:piece_map), p.id], p)
    |> set_stream_changes(p.id)
  end

  defp delete_piece(socket, piece_id) do
    socket
    |> pop_in([Access.key(:assigns), Access.key(:piece_map), piece_id])
    |> elem(1)
    |> set_stream_changes(piece_id)
  end

  def get_slot(socket, slot) do
    socket.assigns.slot_map[slot]
  end

  defp set_slot(socket, slot, changeset \\ %{}) do
    s = get_slot(socket, slot) |> struct(changeset)
    # Logger.warning("SET SLOT #{slot} #{inspect s} #{inspect changeset}")
    socket
    |> put_in([Access.key(:assigns), Access.key(:slot_map), slot], s)
    |> set_stream_changes(slot)
  end

  defp set_stream_changes(socket, id) do
    socket
    |> assign(:stream_changes, [id | socket.assigns.stream_changes])
  end
end
