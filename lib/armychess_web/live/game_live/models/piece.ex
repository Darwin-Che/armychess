defmodule ArmychessWeb.GameLive.Models.Piece do
  defstruct id: "piece_xxx",
            slot: "slot_xxx",
            display: "Empty",
            enabled: false,
            status: ""

  def is_valid_piece(piece) do
    piece != nil and String.starts_with?(piece, "piece_")
  end

  def is_enemy_piece(piece) do
    # "piece_xxx"
    String.at(piece, 6) == "9"
  end

  def is_owned_piece(piece) do
    # "piece_xxx"
    String.at(piece, 6) == "0"
  end

  def atom(piece) do
    String.to_existing_atom(piece)
  end
end
