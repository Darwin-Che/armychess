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
  @reachable_map_sapper reachable_map_sapper(@adjacent_map)

  @reachable_map reachable_map(@reachable_map_sapper)

  def reachable_map() do
    @reachable_map
  end

  def reachable_map(slot) do
    @reachable_map |> Map.get(slot)
  end

  def reachable_map_sapper() do
    @reachable_map_sapper
  end

  def reachable_map_sapper(slot) do
    @reachable_map_sapper |> Map.get(slot)
  end

  def adjacent_map() do
    @adjacent_map
  end

  def adjacent_map(slot) do
    @adjacent_map |> Map.get(slot)
  end
end
