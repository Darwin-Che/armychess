defmodule Armychess.Server.PlaySession do
  use GenServer, restart: :transient

  import Ecto.Query

  alias Armychess.Repo

  require Logger

  @dsup_name Armychess.Server.PlaySession.DSupervisor

  # Caller API

  def name(game_id) do
    {:global, "PlaySession:#{game_id}"}
  end

  def start({_game_id} = args) do
    DynamicSupervisor.start_child(@dsup_name, {__MODULE__, args})
  end

  def start_link({game_id} = args) do
    Logger.info("#{__MODULE__}.start_link game_id=#{game_id}")
    GenServer.start_link(__MODULE__, args, name: name(game_id))
  end

  def join(game_id, player_side) do
    Logger.info("#{__MODULE__}.join game_id=#{game_id}")
    name = name(game_id)
    try do
      GenServer.call(name, {:join, game_id, player_side, self()})
    catch
      :exit, _ ->
        Logger.error("Failed to JOIN #{game_id}, Starting it")
        start({game_id})
        GenServer.call(name, {:join, game_id, player_side, self()})
    end
  end

  # place_list [{piece, slot}]
  def ready(play_session, place_list) do
    resp = GenServer.call(play_session, {:ready, place_list})
    Logger.debug "PlaySession.ready"
    resp
  end

  def attack(play_session, piece, from_slot, to_slot) do
    resp = GenServer.call(play_session, {:attack, piece, from_slot, to_slot})
    Logger.debug "PlaySession.attack #{piece} #{from_slot} #{to_slot} => #{resp}"
    resp
  end

  def reach(play_session, piece, from_slot, to_slot) do
    resp = GenServer.call(play_session, {:reach, piece, from_slot, to_slot})
    Logger.debug "PlaySession.reach #{piece} #{from_slot} #{to_slot} => #{resp}"
    resp
  end

  # Callbacks

  defstruct [
    game_id: nil,
    stream_name: "",

    connected: %{}, # "1" => {view_pid, monitor_ref}
    spear_conn: nil,

    board: %{}, # "slot_1xx" => {"player1", "Colonel"}
    phase: {:create}, # {:create}, {:ready, []}, {:move, "1"}, :end
    # events: [],
  ]

  def init({game_id} = _args) do
    Logger.debug "Armychess.Server.PlaySession.init #{game_id}"

    # In order to trap the exit of the liveview process
    Process.flag(:trap_exit, true)

    {:ok, conn} = Spear.Connection.start_link(connection_string: "esdb://localhost:2113")

    state = %__MODULE__{
      game_id: game_id,
      stream_name: "Game_#{game_id}",
      spear_conn: conn,
    }

    # Read existing messages
    events = Spear.stream!(conn, state.stream_name) |> Enum.to_list()

    state =
      events
      |> Enum.reduce(state, fn %{type: type, body: msg}, state ->
        Logger.debug("Catchup #{type} #{msg}")
        case handle_event(type, msg, state) do
          {:ok, new_state, _} ->
            new_state
          {:error, err} ->
            Logger.error("PlaySession.init handle_event #{type} #{msg} returns #{err}")
            state
          _ ->
            Logger.error("PlaySession.init handle_event #{type} #{msg} returns invalid")
            state
        end
      end)

    {:ok, state}
  end

  # def handle_continue({:join_game}, state) do
  #   game_session = (
  #     from Armychess.Db.GameSession,
  #     where: [game_id: ^state.game_id, player_side: ^"player#{state.player_side}"]
  #   ) |> Repo.one()

  #   session_id = "#{Node.self()}#{self() |> :erlang.pid_to_list()}"

  #   cond do
  #     game_session.session == nil ->
  #       # Create a new session
  #       try do


  #         {:noreply, struct(state, session: session_id), {:continue, {:connected}}}
  #       rescue
  #         e in Ecto.StaleEntryError ->
  #           # Other has this session
  #           {:stop, :normal, state}
  #       end
  #       game_session.session == session_id ->
  #       # The session is duplicated, allowed
  #       {:noreply, struct(state, session: session_id), {:continue, {:connected}}}
  #     true ->
  #       # Other has this session
  #       {:stop, :normal, state}
  #   end
  # end

  def handle_call({:join, game_id, player_side, view_pid}, _from, state) do
    # Check if player_side is already connected
    if Map.get(state.connected, player_side) == nil do
      # player_state = calc_player_state()
      player_state = %{}

      monitor_ref = Process.monitor(view_pid)
      connected = Map.put(state.connected, player_side, {view_pid, monitor_ref})
      :ok = spear_send("player_joined", %{player_side: player_side}, state)
      publish(%{player_joined: player_side}, state)

      {:reply, {:ok, player_state}, struct(state, connected)}
    else
      {:reply, :rejected, state}
    end
  end

  # place_list [{piece, slot}]
  def handle_call({:ready, place_list}, {pid, _} = _from, state) do
    case Enum.filter(state.connected, fn {_, {p, _}} -> p == pid end) do
      [{player_side, _}] ->
        msg = %{"player_side" => player_side, "place_list" => place_list}

        case handle_event("player_ready", msg, state) do
          {:ok, new_state, _} ->
            :ok = spear_send("player_ready", msg, state)
            publish({:player_ready, player_side}, state)
            {:reply, {:ok}, new_state}
          {:error, err} ->
            {:reply, {:rejected, err}, state}
        end
      _ ->
        {:reply, {:rejected, "Player is invalid"}, state}
    end
  end

  def handle_call({:reach, piece, from_slot, to_slot}, {pid, _} = _from, state) do
    case Enum.filter(state.connected, fn {_, {p, _}} -> p == pid end) do
      [{player_side, _}] ->
        from_slot = slot_abs(from_slot, player_side)
        to_slot = slot_abs(to_slot, player_side)
        msg = %{"player_side" => player_side, "piece" => piece, "from_slot" => from_slot, "to_slot" => to_slot}

        case handle_event("player_reach", msg, state) do
          {:ok, new_state, _} ->
            :ok = spear_send("player_reach", msg, new_state)
            publish({:player_reach, player_side, piece, from_slot, to_slot}, state)
            {:reply, {:ok}, new_state}
          {:error, err} ->
            {:reply, {:rejected, err}, state}
        end
      _ ->
        {:reply, {:rejected, "Player is invalid"}, state}
    end
  end

  def handle_call({:attack, piece, from_slot, to_slot}, {pid, _} = _from, state) do
    case Enum.filter(state.connected, fn {_, {p, _}} -> p == pid end) do
      [{player_side, _}] ->
        from_slot = slot_abs(from_slot, player_side)
        to_slot = slot_abs(to_slot, player_side)
        msg = %{"player_side" => player_side, "piece" => piece, "from_slot" => from_slot, "to_slot" => to_slot}

        case handle_event("player_attack", msg, state) do
          {:ok, new_state, attack_result} ->
            :ok = spear_send("player_attack", msg, new_state)
            publish({:player_attack, player_side, piece, from_slot, to_slot, attack_result}, state)
            {:reply, {:ok, attack_result}, new_state}
          {:error, err} ->
            {:reply, {:rejected, err}, state}
        end
      _ ->
        {:reply, {:rejected, "Player is invalid"}, state}
    end
  end

  # return {:ok, state, term()} or {:error, String} to reject the event
  defp handle_event(type, msg, state) do
    Logger.debug("PlaySession handle_event #{type} #{msg}")

    case type do
      "game_move" ->
        case msg["move"] do
          "reach" -> handle_event_reach(msg, state)
          "attack" -> handle_event_attack(msg, state)
          _ -> Logger.error("Received Invalid Event")
        end
      "player_ready" ->
        handle_event_ready(msg, state)
      _ ->
        state
    end
  end

  defp handle_event_ready(%{"player_side" => player_side, "place_list" => place_list}, state) do
    case state.phase do
      {:ready, ready_list} ->
        if player_side |> Enum.member?(ready_list) do
          {:error, "Player #{player_side} already submitted place_list"}
        else
          # TODO: Verify place_list
          # Insert into board
          board = Enum.reduce(place_list, state.board, fn {piece, slot}, board ->
            board |> Map.put(slot_abs(slot, state.player_side), {state.player_side, piece})
          end)
          # If both players are ready
          phase =
            if ready_list != [] do
              {:move, ready_list |> List.first()}
            else
              {:ready, [player_side]}
            end

          {:ok, struct(state, board: board, phase: phase), nil}
        end

      _ ->
        {:error, "The game is not expecting place_list submission"}
    end
  end

  defp handle_event_reach(%{
      "player_side" => player_side,
      "piece" => piece,
      "from_slot" => from_slot,
      "to_slot" => to_slot}, state) do
    cond do
      state.phase != {:move, player_side} ->
        {:error, "The game is not expecting move from #{player_side}"}

      state.board[from_slot] != {player_side, piece} ->
        {:error, "The from slot #{from_slot} doesn't have #{piece} for #{player_side}"}

      state.board[to_slot] != nil ->
        {:error, "The to slot #{to_slot} is not empty"}

      to_slot not in reachable_list(state.board, from_slot) ->
        {:error, "The to slot #{to_slot} is not reachable"}

      true ->
        new_board =
          state.board
          |> Map.put(to_slot, state.board[from_slot])
          |> Map.delete(from_slot)

        {:ok, struct(state, board: new_board), nil}
    end
  end

  defp handle_event_attack(%{
      "player_side" => player_side,
      "piece" => piece,
      "from_slot" => from_slot,
      "to_slot" => to_slot}, state) do
    cond do
      state.phase != {:move, player_side} ->
        {:error, "The game is not expecting move from #{player_side}"}

      state.board[from_slot] != {player_side, piece} ->
        {:error, "The from slot #{from_slot} doesn't have #{piece} for #{player_side}"}

      state.board[to_slot] == nil ->
        {:error, "The to slot #{to_slot} is empty"}

      to_slot not in attackable_list(state.board, from_slot) ->
        {:error, "The to slot #{to_slot} is not reachable"}

      true ->
        attack_result = Armychess.Entity.Piece.cmp(piece, state.board[to_slot] |> elem(1))

        new_board =
          case attack_result do
            :win ->
              state.board
              |> Map.put(to_slot, state.board[from_slot])
              |> Map.delete(from_slot)
            :lose ->
              state.board
              |> Map.delete(from_slot)
            :draw ->
              state.board
              |> Map.delete(from_slot)
              |> Map.delete(to_slot)
          end

        {:ok, struct(state, board: new_board), attack_result}
    end
  end

  def handle_info({:DOWN, ref, :process, view_pid, _reason}, state) do
    IO.puts(":DOWN #{inspect view_pid}")

    filtered =
      Enum.filter(state.connected, fn {_, {p, _}} -> p == view_pid end)

    case filtered do
      [] ->
        Logger.error("PlaySession Received Invalid DOWN Message!")
        Process.demonitor(ref)
        {:noreply, state}

      [{player_side, {_, monitor_ref}}] ->
        Process.demonitor(monitor_ref)

        connected = state.connected |> Map.delete(player_side)
        state = struct(state, connected: connected)

        :ok = spear_send("player_left", %{player_side: player_side}, state)
        publish({{:player_left, player_side}}, state)

        {:noreply, state}
    end
  end

  def terminate(reason, state) do
    Logger.info("PlaySession TERMINATE #{state.game_id} #{state.player_side}")
  end

  ### HELPER FUNCTIONS

  defp publish(msg, state) do
    for {player_side, view_pid} <- state.connected do
      send(view_pid, msg)
    end
  end

  # defp spear_subscribe(state) do
  #   if state.events == [] do
  #     Spear.subscribe(state.spear_conn, self(), state.stream_name)
  #   else
  #     Spear.subscribe(state.spear_conn, self(), state.stream_name, from: state.events |> List.first())
  #   end
  # end

  defp spear_send(type, msg, state, opts \\ []) do
    [Spear.Event.new(type, msg)]
    |> Spear.append(state.spear_conn, state.stream_name, opts)
  end

  defp other_side(player_side) do
    case player_side do
      "1" -> "2"
      "2" -> "1"
    end
  end

  # player_side = "1" or "2"
  defp slot_abs(s, player_side) do
    s
    |> String.replace("_0", "_#{player_side}")
    |> String.replace("_9", "_#{other_side(player_side)}")
  end

  defp slot_rel(s, player_side) do
    s
    |> String.replace("_#{player_side}", "_0")
    |> String.replace("_#{other_side(player_side)}", "_9")
  end

  defp reachable_list(board, from_slot) do
    reachable_or_attackable_list(board, from_slot) |> elem(1)
  end

  defp attackable_list(board, from_slot) do
    reachable_or_attackable_list(board, from_slot) |> elem(0)
  end

  defp reachable_or_attackable_list(board, from_slot) do
    {player_side, piece} = board[from_slot]

    paths = if piece == "Sapper" do
      Armychess.Entity.Slot.reachable_map_sapper(slot_rel(from_slot, player_side))
    else
      Armychess.Entity.Slot.reachable_map(slot_rel(from_slot, player_side))
    end

    result_list = for path <- paths do
      Enum.reduce_while(path |> List.delete_at(0), {[], []}, fn s, {slots_attack, slots_reach} ->
        {player_side, piece} =
        case Map.get(board, slot_abs(s, player_side)) do
          nil ->
            {:cont, {slots_attack, [s | slots_reach]}}
          {side, _} when side != player_side ->
            {:halt, {[s | slots_attack], slots_reach}}
          _ ->
            {:halt, {slots_attack, slots_reach}}
        end
      end)
    end

    slots_attack = Enum.map(result_list, fn {a, _r} -> a end) |> List.flatten() |> Enum.uniq() |> Enum.map(&(slot_abs(&1, player_side)))
    slots_reach =  Enum.map(result_list, fn {_a, r} -> r end) |> List.flatten() |> Enum.uniq() |> Enum.map(&(slot_abs(&1, player_side)))

    {slots_attack, slots_reach}
  end
end
