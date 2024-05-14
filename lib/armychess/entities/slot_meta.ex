defmodule Armychess.Entity.SlotMeta do
  def edges_one_side(s) do
    # horizontal lines
    horizontal_lines =
      for r <- 1..6, c <- 1..4 do
        {"slot_#{s}#{r}#{c}", "slot_#{s}#{r}#{c + 1}", r == 1 or r == 5}
      end

    # vertical lines
    vertical_lines =
      for c <- 1..5, r <- 1..5 do
        {"slot_#{s}#{r}#{c}", "slot_#{s}#{r + 1}#{c}", (c == 1 or c == 5) and r != 5}
      end

    # slashes
    slashes =
      for {r, c} <- [{2, 2}, {2, 4}, {3, 3}, {4, 2}, {4, 4}] do
        [
          {"slot_#{s}#{r}#{c}", "slot_#{s}#{r + 1}#{c + 1}", false},
          {"slot_#{s}#{r}#{c}", "slot_#{s}#{r - 1}#{c + 1}", false},
          {"slot_#{s}#{r}#{c}", "slot_#{s}#{r + 1}#{c - 1}", false},
          {"slot_#{s}#{r}#{c}", "slot_#{s}#{r - 1}#{c - 1}", false}
        ]
      end

    [horizontal_lines, vertical_lines, slashes] |> List.flatten()
  end

  # %{"slot_0xx" => {[:rails], [:roads]}}
  # edges = [{"slot_0xx", "slot_9xx", true/false}]
  def adjacent_map(edges) do
    List.foldl(edges, %{}, fn {src, dest, bool_rail}, acc ->
      acc
      |> Map.update(src, [{dest, bool_rail}], fn val ->
        [{dest, bool_rail} | val]
      end)
      |> Map.update(dest, [{src, bool_rail}], fn val ->
        [{src, bool_rail} | val]
      end)
    end)
    # %{"slot_0xx" => [{"slot_9xx", true}]}
    |> Enum.map(fn {src, dests} ->
      {
        src,
        List.foldl(dests, {[], []}, fn {dest, bool_rail}, {acc_rail, acc_road} ->
          if bool_rail do
            {[dest | acc_rail], acc_road}
          else
            {acc_rail, [dest | acc_road]}
          end
        end)
      }
    end)
    |> Map.new()
  end

  # %{"slot_0xx" => [["slot_0xx", "slot_0yy", "slot_0aa"], []]}
  # adjacent_map = %{"slot_0xx" => {[:rails], [:roads]}}
  def reachable_map_sapper(adjacent_map) do
    for s <- [0, 9], r <- 1..6, c <- 1..5 do
      slot = "slot_#{s}#{r}#{c}"
      {slot, reachable_paths(adjacent_map, slot)}
    end
    |> Map.new()
  end

  # [["slot_0xx", "slot_0yy", "slot_0aa"], []]
  defp reachable_paths(adjacent_map, slot) do
    {_, road_slots} = Map.get(adjacent_map, slot)

    reachable_paths_rail =
      reachable_paths_rail(adjacent_map, [slot])
      |> Enum.map(fn path -> Enum.reverse(path) end)

    reachable_paths_road =
      for road_slot <- road_slots do
        [slot, road_slot]
      end

    [reachable_paths_road, reachable_paths_rail] |> Enum.flat_map(& &1)
  end

  # return a list of paths
  defp reachable_paths_rail(adjacent_map, path) do
    {rail_slots, _} = Map.get(adjacent_map, List.first(path))

    rail_paths =
      for rail_slot <- rail_slots do
        if Enum.member?(path, rail_slot) do
          []
        else
          reachable_paths_rail(adjacent_map, [rail_slot | path])
        end
      end
      |> Enum.flat_map(& &1)

    if length(rail_paths) == 0 do
      [path]
    else
      rail_paths
    end
  end

  def reachable_map(reachable_map_sapper) do
    reachable_map_sapper
    |> Enum.map(fn {k, v} ->
      {
        k,
        v
        |> Enum.map(&cut_straight_path/1)
        |> remove_prefix_duplicate()
      }
    end)
    |> Map.new()
  end

  # %{"slot_0xx" => [["slot_0xx", "slot_0yy", "slot_0aa"], []]}
  def reachable_map_convert_to_abs(reachable_map) do
    # simple convert all 0 to 1 and 0 to 2
    reachable_map
    |> Map.new(fn {src, paths} ->
      {
        src |> convert_to_abs(),
        paths
        |> Enum.map(fn path ->
          path |> Enum.map(&convert_to_abs/1)
        end)
      }
    end)
  end

  defp convert_to_abs(slot) do
    slot
    |> String.replace("_0", "_1")
    |> String.replace("_9", "_2")
  end

  defp same_direction(prev_slot, _slot, next_slot) do
    prev_slot_s = prev_slot |> String.at(-3)
    prev_slot_r = prev_slot |> String.at(-2)
    prev_slot_c = prev_slot |> String.at(-1)

    next_slot_s = next_slot |> String.at(-3)
    next_slot_r = next_slot |> String.at(-2)
    next_slot_c = next_slot |> String.at(-1)

    slot_c_bool =
      if prev_slot_s == next_slot_s do
        prev_slot_c == next_slot_c
      else
        {prev_slot_c, _} = Integer.parse(prev_slot_c)
        {next_slot_c, _} = Integer.parse(next_slot_c)
        6 - prev_slot_c == next_slot_c
      end

    slot_r_bool = prev_slot_s == next_slot_s and prev_slot_r == next_slot_r

    slot_c_bool or slot_r_bool
  end

  defp cut_straight_path(path) do
    Enum.reduce_while(path, [], fn slot, new_path ->
      case new_path do
        [prev | [prev_prev | _]] ->
          if same_direction(prev_prev, prev, slot) do
            {:cont, [slot | new_path]}
          else
            {:halt, new_path}
          end

        _ ->
          {:cont, [slot | new_path]}
      end
    end)
    |> Enum.reverse()
  end

  defp remove_prefix_duplicate(paths) do
    paths = Enum.sort_by(paths, fn path -> length(path) end)
    remove_prefix_helper([], paths)
  end

  defp remove_prefix_helper(results, []) do
    results
  end

  defp remove_prefix_helper(results, [path | longer_paths]) do
    is_dup =
      Enum.reduce_while(longer_paths, false, fn longer_path, _ ->
        if List.starts_with?(longer_path, path) do
          {:halt, true}
        else
          {:cont, false}
        end
      end)

    if is_dup do
      remove_prefix_helper(results, longer_paths)
    else
      remove_prefix_helper([path | results], longer_paths)
    end
  end
end
