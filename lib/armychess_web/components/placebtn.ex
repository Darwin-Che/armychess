defmodule ArmychessWeb.Components.Placebtn do
  use Phoenix.Component

  def placebtn(assigns) do
    ~H"""
    <div class="flex w-[150px] gap-[20px] justify-items-center	items-center">
      <button
        id={"placebtn_#{@p}"}
        class={"#{if @p == @selected do "placebtn_selected" else "" end}"}
        phx-click="click-placebtn"
        phx-value-id={@p}
      >
        <img class="piece_img" src={"/images/piece_#{@p}.svg"} />
      </button>
      <p>
        &times <%= @cnt[@p] || 0 %>
      </p>
    </div>
    """
  end
end
