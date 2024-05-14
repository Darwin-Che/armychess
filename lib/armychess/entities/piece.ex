defmodule Armychess.Entity.Piece do
  @pieces [
    {"Landmine", 3},
    {"President", 1},
    {"General", 1},
    {"Colonel", 2},
    {"Major", 2},
    {"Captain", 2},
    {"Lieutenant", 2},
    {"Sergeant", 3},
    {"Corporal", 3},
    {"Sapper", 3},
    {"Bomb", 2},
    {"HQ", 1},
  ]

  @names @pieces |> Enum.map(fn {name, _} -> name end)

  @rank_map @names |> Enum.with_index(fn name, idx -> {name, idx} end) |> Map.new()

  def cmp("Sapper", "Landmine"), do: :win
  def cmp("Landmine", "Sapper"), do: :lose

  def cmp("Sapper", "Bomb"), do: :win
  def cmp("Bomb", "Sapper"), do: :lose

  def cmp("Bomb", _), do: :draw
  def cmp(_, "Bomb"), do: :draw

  def cmp(p1, p2) when p1 == p2, do: :draw

  def cmp(p1, p2) do
    r1 = @rank_map[p1]
    r2 = @rank_map[p2]
    cond do
      r1 > r2 -> :lose
      r1 == r2 -> :draw
      r1 < r2 -> :win
    end
  end

  def available_list() do
    [
      {"HQ", 1},
      {"Landmine", 3},
      {"Bomb", 2},
      {"President", 1},
      {"General", 1},
      {"Colonel", 2},
      {"Major", 2},
      {"Captain", 2},
      {"Lieutenant", 2},
      {"Sergeant", 3},
      {"Corporal", 3},
      {"Sapper", 3},
    ]
  end

  def placeable_slots("HQ") do
    ["slot_062", "slot_064"]
  end

  def placeable_slots("Landmine") do
    for r <- (5..6), c <- (1..5) do
      "slot_0#{r}#{c}"
    end
  end

  def placeable_slots(_) do
    for r <- (1..6), c <- (1..5) do
      "slot_0#{r}#{c}"
    end
    |> List.delete("slot_022")
    |> List.delete("slot_024")
    |> List.delete("slot_033")
    |> List.delete("slot_042")
    |> List.delete("slot_044")
  end
end
# HQ         * 1
# President  * 1
# General    * 1
# Colonel    * 2
# Major      * 2
# Captain    * 2
# Lieutenant * 2
# Sergeant   * 3
# Corporal   * 3
# Sapper     * 3
# Landmine   * 3
# Bomb       * 2
