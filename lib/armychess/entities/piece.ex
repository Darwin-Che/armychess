defmodule Armychess.Entity.Piece do
  @names [
    "Landmine",
    "President",
    "General",
    "Colonel",
    "Major",
    "Captain",
    "Lieutenant",
    "Sergeant",
    "Corporal",
    "Sapper",
    "Bomb",
    "HQ",
  ]

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
