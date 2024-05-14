defmodule ArmychessWeb.GameLive.Models.Game do
  require Logger

  alias ArmychessWeb.GameLive.Models.Piece
  alias ArmychessWeb.GameLive.Models.Slot

  defstruct id: "",
            # "slot_xxx" -> %Slot{}
            slot_map: %{},
            # "slot_xxx" -> "piece_xxx"
            board_map: %{},
            # "piece_xxx" -> %Piece{}
            piece_map: %{},
            # "piece_xxx"
            update_list_piece: [],
            # "piece_xxx"
            update_list_slot: []

  def from_socket(socket) do
    socket.assigns.game
  end

  defp updated_piece(game, x) do
    game
    |> Map.update!(:update_list_piece, fn l -> [x | l] end)
  end

  defp updated_slot(game, x) do
    game
    |> Map.update!(:update_list_slot, fn l -> [x | l] end)
  end

  ## Pieces

  def get_pieces(game, pieces) do
    for piece <- pieces do
      game.piece_map[piece]
    end
  end

  def get_piece(game, piece) do
    game.piece_map[piece]
  end

  def set_pieces(game, pieces, changeset \\ %{}) do
    game
    |> Map.update!(:piece_map, fn bm ->
      List.foldl(pieces, bm, fn piece, bm ->
        Map.update!(bm, piece, fn pc ->
          struct(pc, changeset)
        end)
      end)
    end)
    |> updated_piece(pieces)
  end

  def set_piece(game, piece, changeset \\ %{}) do
    p = get_piece(game, piece) |> struct(changeset)

    game
    |> put_in([Access.key(:piece_map), piece], p)
    |> updated_piece(piece)
  end

  def set_pieces_mark(game, pieces, mark) do
    slots = get_pieces(game, pieces) |> Enum.map(fn piece -> piece.slot end)

    game
    |> set_slots_mark(slots, mark)
  end

  def set_piece_move(game, piece, to_slot) do
    p = get_piece(game, piece)
    from_slot = p.slot

    game
    |> set_piece(piece, slot: to_slot)
    |> set_board(from_slot, nil)
    |> set_board(to_slot, piece)
  end

  defp set_board(game, nil, piece) do
    game
  end

  defp set_board(game, slot, nil) do
    game
    |> Map.update!(:board_map, fn bm ->
      Map.delete(bm, slot)
    end)
  end

  defp set_board(game, slot, piece) do
    game
    |> Map.update!(:board_map, fn bm ->
      Map.put(bm, slot, piece)
    end)
  end

  ## Slots

  def reset_slots(game) do
    reset_slots =
      Enum.filter(game.slot_map, fn {k, v} ->
        v.enabled or v.mark != nil
      end)

    List.foldl(reset_slots, game, fn {k, v}, game ->
      reset_slot(game, k)
    end)
  end

  def reset_slot(game, slot) do
    game
    |> Map.update!(:slot_map, fn sm ->
      Map.update!(sm, slot, fn s ->
        struct(s, enabled: false, mark: nil)
      end)
    end)
    |> updated_slot(slot)
  end

  def get_slots(game, slots) do
    for slot <- slots do
      game.slot_map[slot]
    end
  end

  def set_slots_enabled(game, slots) do
    game
    |> Map.update!(:slot_map, fn sm ->
      List.foldl(slots, sm, fn slot, sm ->
        Map.update!(sm, slot, fn s ->
          struct(s, enabled: true)
        end)
      end)
    end)
    |> updated_slot(slots)
  end

  def set_slots_disabled(game, slots) do
    game
    |> Map.update!(:slot_map, fn sm ->
      List.foldl(slots, sm, fn slot, sm ->
        Map.update!(sm, slot, fn s ->
          struct(s, enabled: false)
        end)
      end)
    end)
    |> updated_slot(slots)
  end

  def set_slots_mark(game, slots, mark) do
    game
    |> Map.update!(:slot_map, fn sm ->
      List.foldl(slots, sm, fn slot, sm ->
        Map.update!(sm, slot, fn s ->
          struct(s, mark: mark)
        end)
      end)
    end)
    |> updated_slot(slots)
  end

  ## Find selectible targets

  # This returns a tuple of list {[piece], [slot]}
  def get_selectable_targets(game, piece) do
    board_map = game.board_map

    piece = get_piece(game, piece)

    paths =
      if piece.display == "Sapper" do
        Armychess.Entity.Slot.reachable_map_sapper(piece.slot)
      else
        Armychess.Entity.Slot.reachable_map(piece.slot)
      end

    # |> IO.inspect

    result_list =
      for path <- paths do
        Enum.reduce_while(path |> List.delete_at(0), {[], []}, fn s, {pieces, slots} ->
          p = Map.get(board_map, s)

          cond do
            p == nil ->
              {:cont, {pieces, [s | slots]}}

            Piece.is_enemy_piece(p) ->
              {:halt, {[p | pieces], slots}}

            true ->
              {:halt, {pieces, slots}}
          end
        end)
      end

    pieces = Enum.map(result_list, fn {p, _s} -> p end) |> List.flatten() |> Enum.uniq()
    slots = Enum.map(result_list, fn {_p, s} -> s end) |> List.flatten() |> Enum.uniq()
    {pieces, slots}
    # |> IO.inspect
  end

  ## Helpers

  def all_pieces(game) do
    game.piece_map |> Map.values()
  end

  def all_slots(game) do
    game.slot_map |> Map.values()
  end

  ## Initialize

  def load(id \\ "") do
    Logger.info("Game.load #{id}")
    # Fetch the Game State with id from Server
    %__MODULE__{
      id: id,
      slot_map: tmp_slot_map(),
      board_map: tmp_board_map(),
      piece_map: tmp_piece_map()
    }
  end

  defp tmp_slot_map() do
    slots =
      for s <- [0, 9], c <- 1..5, r <- 1..6 do
        %Slot{
          id: "slot_#{s}#{r}#{c}"
        }
      end

    slots
    |> Map.new(fn slot -> {slot.id, slot} end)
  end

  defp tmp_board_map() do
    Map.new(
      tmp_piece_map(),
      fn {k, v} ->
        {v.slot, k}
      end
    )
  end

  defp tmp_piece_map() do
    owned_pieces = %{
      "piece_011" => "President",
      "piece_012" => "General",
      "piece_013" => "Colonel",
      "piece_014" => "Colonel",
      "piece_015" => "Major",
      "piece_021" => "Major",
      # "piece_022" => "Captain",
      "piece_023" => "Captain",
      # "piece_024" => "Lieutenant",
      "piece_025" => "Captain",
      "piece_031" => "Lieutenant",
      "piece_032" => "Lieutenant",
      # "piece_033" => "Corporal",
      "piece_034" => "Sergeant",
      "piece_035" => "Sergeant",
      "piece_041" => "Sergeant",
      # "piece_042" => "Landmine",
      "piece_043" => "Corporal",
      # "piece_044" => "Landmine",
      "piece_045" => "Corporal",
      "piece_051" => "Corporal",
      "piece_052" => "Sapper",
      "piece_053" => "Sapper",
      "piece_054" => "Sapper",
      "piece_055" => "Landmine",
      "piece_061" => "Landmine",
      "piece_062" => "Landmine",
      "piece_063" => "Bomb",
      "piece_064" => "HQ",
      "piece_065" => "Bomb"
    }

    enemy_pieces =
      for {k, _} <- owned_pieces do
        r = String.at(k, -2)
        c = String.at(k, -1)

        {"piece_9#{r}#{c}",
         %Piece{
           id: "piece_9#{r}#{c}",
           slot: "slot_9#{r}#{c}",
           display: "Empty",
           enabled: false
         }}
      end
      |> Map.new()

    piece_map =
      Map.new(owned_pieces, fn {k, v} ->
        {k,
         %Piece{
           id: k,
           slot: String.replace_leading(k, "piece", "slot"),
           display: v,
           enabled: v != "HQ" and v != "Landmine"
         }}
      end)
      |> Map.merge(enemy_pieces)
  end
end
