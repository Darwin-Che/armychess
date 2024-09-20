# Armychess

## Game States
This is transparent to both players
```
{:ready, ["1"]} // The list of ready players
{:move, "1"} // Player 1 should make a move
{:end, "1"} // Player 1 wins (nil means draw)
{:pause_draw, "1"} // Pause for a draw request by Player 1
```

## Controller Messages

### ready
```
{
  place_map: {
    slot_011: "Lietenant",
    ...
  }
}
```

### attack
```
{
  from_slot: "slot_011",
  to_slot: "slot_951",
}
```

### reach
```
{
  from_slot: "slot_011",
  to_slot: "slot_951",
}
```

### surrender
```
{}
```

### draw_req
```
{}
```

### draw_resp
```
{
  agree: "yes" / "no"
}
```

## Game Log

Same thing as the controller messages except that a player id is add to the struct.

## View Messages

### state
State update is a type of message that contains every view updates on everything other than the pieces.
```
{
  state,
}
```

### reach
Only for the reach update. (Should be accompanied by a state update)
```
{
  player_side: "1",
  from_slot: "slot_034",
  to_slot: "slot_024"
}
```

### attack
Only for the reach update. (Should be accompanied by a state update)

```
{
  player_side: "1",
  from_slot: "slot_034",
  to_slot: "slot_024",
  result: "win" / "lose",
}
```
