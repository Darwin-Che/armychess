defmodule ArmychessWeb.Components.CssHelper do
  use Phoenix.Component

  @slot_pos %{
    c_0_arr: [15, 137, 260, 382, 505],
    r_0_arr: [550, 615, 680, 745, 810, 870],
    c_9_arr: [15, 137, 260, 382, 505] |> Enum.reverse(),
    r_9_arr: [40, 100, 165, 230, 295, 360] |> Enum.reverse(),
  }

  @slot_round [
    "slot_022",
    "slot_024",
    "slot_033",
    "slot_042",
    "slot_044",

    "slot_922",
    "slot_924",
    "slot_933",
    "slot_942",
    "slot_944",
  ]

  def markpos() do
    # this is an unfortunate workaround to inject into root.html
    assigns = %{
      c_0_arr: @slot_pos.c_0_arr |> Enum.map(fn x -> x - 19 end),
      r_0_arr: @slot_pos.r_0_arr |> Enum.map(fn x -> x - 11 end),
      c_9_arr: @slot_pos.c_9_arr |> Enum.map(fn x -> x - 19 end),
      r_9_arr: @slot_pos.r_9_arr |> Enum.map(fn x -> x - 11 end),
    }


    ~H"""
    <%= for {cval, cidx} <- Enum.with_index(@c_0_arr), {rval, ridx} <- Enum.with_index(@r_0_arr) do %>
    [id=<%="mark_slot_0#{ridx + 1}#{cidx + 1}"%>] {
      left: <%="#{cval}px"%>;
      top: <%="#{rval}px"%>;
    }
    <% end %>
    <%= for {cval, cidx} <- Enum.with_index(@c_9_arr), {rval, ridx} <- Enum.with_index(@r_9_arr) do %>
    [id=<%="mark_slot_9#{ridx + 1}#{cidx + 1}"%>] {
      left: <%="#{cval}px"%>;
      top: <%="#{rval}px"%>;
    }
    <% end %>
    """
  end


  def btnpos() do
    # this is an unfortunate workaround to inject into root.html
    assigns = %{
      c_0_arr: @slot_pos.c_0_arr |> Enum.map(fn x -> x - 15 end),
      r_0_arr: @slot_pos.r_0_arr |> Enum.map(fn x -> x - 7 end),
      c_9_arr: @slot_pos.c_9_arr |> Enum.map(fn x -> x - 15 end),
      r_9_arr: @slot_pos.r_9_arr |> Enum.map(fn x -> x - 7 end),
    }


    ~H"""
    <%= for {cval, cidx} <- Enum.with_index(@c_0_arr), {rval, ridx} <- Enum.with_index(@r_0_arr) do %>
    [btnpos=<%="slot_0#{ridx + 1}#{cidx + 1}"%>] {
      left: <%="#{cval}px"%>;
      top: <%="#{rval}px"%>;
    }
    <% end %>
    <%= for {cval, cidx} <- Enum.with_index(@c_9_arr), {rval, ridx} <- Enum.with_index(@r_9_arr) do %>
    [btnpos=<%="slot_9#{ridx + 1}#{cidx + 1}"%>] {
      left: <%="#{cval}px"%>;
      top: <%="#{rval}px"%>;
    }
    <% end %>
    """
  end

  def slotpos() do
    # this is an unfortunate workaround to inject into root.html
    assigns = Map.put(@slot_pos, :slot_round, @slot_round)

    ~H"""
    <%= for {cval, cidx} <- Enum.with_index(@c_0_arr), {rval, ridx} <- Enum.with_index(@r_0_arr) do %>
    [id=<%="slot_0#{ridx + 1}#{cidx + 1}"%>] {
      left: <%="#{cval}px"%>;
      top: <%="#{rval}px"%>;
      border-radius: <%= if Enum.member?(@slot_round, "slot_0#{ridx + 1}#{cidx + 1}") do "50%" else "10%" end%>;
    }
    <% end %>
    <%= for {cval, cidx} <- Enum.with_index(@c_9_arr), {rval, ridx} <- Enum.with_index(@r_9_arr) do %>
    [id=<%="slot_9#{ridx + 1}#{cidx + 1}"%>] {
      left: <%="#{cval}px"%>;
      top: <%="#{rval}px"%>;
      border-radius: <%= if Enum.member?(@slot_round, "slot_9#{ridx + 1}#{cidx + 1}") do "50%" else "10%" end%>;
    }
    <% end %>
    """
  end
end
