defmodule ArmychessWeb.Components.CssHelper do
  use Phoenix.Component

  @slot_pos %{
    c_0_arr: [3.2, 23.6, 44, 64.4, 84.8],
    r_0_arr: [59, 66.1, 73.2, 80.3, 87.4, 94.7],
    c_9_arr: [3.2, 23.6, 44, 64.4, 84.8] |> Enum.reverse(),
    r_9_arr: [1.8, 8.9, 16, 23.2, 30.4, 37.5] |> Enum.reverse(),
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
      c_0_arr: @slot_pos.c_0_arr |> Enum.map(fn x -> x - 1.8 end),
      r_0_arr: @slot_pos.r_0_arr |> Enum.map(fn x -> x - 0.9 end),
      c_9_arr: @slot_pos.c_9_arr |> Enum.map(fn x -> x - 1.8 end),
      r_9_arr: @slot_pos.r_9_arr |> Enum.map(fn x -> x - 0.9 end),
    }


    ~H"""
    <%= for {cval, cidx} <- Enum.with_index(@c_0_arr), {rval, ridx} <- Enum.with_index(@r_0_arr) do %>
    [id=<%="mark_slot_0#{ridx + 1}#{cidx + 1}"%>] {
      left: <%="#{cval}%"%>;
      top: <%="#{rval}%"%>;
    }
    <% end %>
    <%= for {cval, cidx} <- Enum.with_index(@c_9_arr), {rval, ridx} <- Enum.with_index(@r_9_arr) do %>
    [id=<%="mark_slot_9#{ridx + 1}#{cidx + 1}"%>] {
      left: <%="#{cval}%"%>;
      top: <%="#{rval}%"%>;
    }
    <% end %>
    """
  end


  def btnpos() do
    # this is an unfortunate workaround to inject into root.html
    assigns = %{
      c_0_arr: @slot_pos.c_0_arr |> Enum.map(fn x -> x - 1.2 end),
      r_0_arr: @slot_pos.r_0_arr |> Enum.map(fn x -> x - 0.5 end),
      c_9_arr: @slot_pos.c_9_arr |> Enum.map(fn x -> x - 1.2 end),
      r_9_arr: @slot_pos.r_9_arr |> Enum.map(fn x -> x - 0.5 end),
    }


    ~H"""
    <%= for {cval, cidx} <- Enum.with_index(@c_0_arr), {rval, ridx} <- Enum.with_index(@r_0_arr) do %>
    [btnpos=<%="slot_0#{ridx + 1}#{cidx + 1}"%>] {
      left: <%="#{cval}%"%>;
      top: <%="#{rval}%"%>;
    }
    <% end %>
    <%= for {cval, cidx} <- Enum.with_index(@c_9_arr), {rval, ridx} <- Enum.with_index(@r_9_arr) do %>
    [btnpos=<%="slot_9#{ridx + 1}#{cidx + 1}"%>] {
      left: <%="#{cval}%"%>;
      top: <%="#{rval}%"%>;
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
      left: <%="#{cval}%"%>;
      top: <%="#{rval}%"%>;
      border-radius: <%= if Enum.member?(@slot_round, "slot_0#{ridx + 1}#{cidx + 1}") do "50%" else "10%" end%>;
    }
    <% end %>
    <%= for {cval, cidx} <- Enum.with_index(@c_9_arr), {rval, ridx} <- Enum.with_index(@r_9_arr) do %>
    [id=<%="slot_9#{ridx + 1}#{cidx + 1}"%>] {
      left: <%="#{cval}%"%>;
      top: <%="#{rval}%"%>;
      border-radius: <%= if Enum.member?(@slot_round, "slot_9#{ridx + 1}#{cidx + 1}") do "50%" else "10%" end%>;
    }
    <% end %>
    """
  end
end
