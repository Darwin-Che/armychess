defmodule Armychess.Entity.Slot do
  # There are 30 Slot per side of map
  # We id them as "{row}{col}" from "11" (top left) to "65"
  # We code the sides different in the client and db
  # In the client, self is "0xx", enemy is "9xx"
  # In the db, host 1 is "1xx", host 2 is "2xx".

  import Armychess.Entity.SlotMeta

  # [{"slot_0xx", "slot_9xx", true/false}]
  @edges [
    edges_one_side(0),
    edges_one_side(9),
    {"slot_011", "slot_915", true},
    {"slot_013", "slot_913", true},
    {"slot_015", "slot_911", true},
  ] |> List.flatten()

  # %{"slot_0xx" => {[:rails], [:roads]}}
  @adjacent_map adjacent_map(@edges)

  # %{"slot_0xx" => [["slot_0xx", "slot_0yy", "slot_0aa"], []]}
  @reachable_map_rel_sapper reachable_map_sapper(@adjacent_map)
  @reachable_map_abs_sapper reachable_map_convert_to_abs(@reachable_map_rel_sapper)

  @reachable_map_rel reachable_map(@reachable_map_rel_sapper)
  @reachable_map_abs reachable_map_convert_to_abs(@reachable_map_rel)

  def get_reachable_map(slot) do
    (@reachable_map_rel |> Map.get(slot)) || (@reachable_map_abs |> Map.get(slot))
  end

  def get_reachable_map_sapper(slot) do
    (@reachable_map_rel_sapper |> Map.get(slot)) || (@reachable_map_abs_sapper |> Map.get(slot))
  end

  def adjacent_map() do
    @adjacent_map
  end

  def adjacent_map(slot) do
    @adjacent_map |> Map.get(slot)
  end

  def get_reachable(_, "Landmine", _) do
    {[], []}
  end

  def get_reachable(_, "HQ", _) do
    {[], []}
  end

  def get_reachable(slot, display, get_piece_fun, is_enemy_fun) do
    paths = if display == "Sapper" do
        get_reachable_map_sapper(slot)
      else
        get_reachable_map(slot)
      end

    result_list = for path <- paths do
      Enum.reduce_while(path |> List.delete_at(0), {[], []}, fn s, {pieces, slots} ->
        p = get_piece_fun.(s)
        cond do
          p == nil ->
            {:cont, {pieces, [s | slots]}}
          is_enemy_fun.(p) && !is_camp_slot(s) ->
            {:halt, {[s | pieces], slots}}
          true ->
            {:halt, {pieces, slots}}
        end
      end)
    end

    pieces = Enum.map(result_list, fn {p, _s} -> p end) |> List.flatten() |> Enum.uniq()
    slots =  Enum.map(result_list, fn {_p, s} -> s end) |> List.flatten() |> Enum.uniq()
    {pieces, slots}
  end

  def is_camp_slot(slot) do
    String.slice(slot, -2..-1) in ["22", "24", "42", "44", "33"]
  end
end
