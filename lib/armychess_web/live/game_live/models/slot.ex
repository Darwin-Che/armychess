defmodule ArmychessWeb.GameLive.Models.Slot do
  defstruct [
    id: "slot_xxx",
    enabled: false,
    mark: nil,
  ]

  def is_valid_slot(slot) do
    slot != nil
  end
end
