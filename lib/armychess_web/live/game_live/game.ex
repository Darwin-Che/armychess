defmodule ArmychessWeb.GameLive.Game do
  use ArmychessWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
