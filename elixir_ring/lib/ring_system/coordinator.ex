defmodule RingSystem.Coordinator do
  @moduledoc """
  Orchestrates the four rings, reads stdin, routes integers, and collects results.
  """

  use GenServer

  alias RingSystem.{RingManager, Token, Transforms, PerfTracker}

  defstruct [:rings, :perf, :n, :h, pending_count: 0, done_reading: false, token_counter: 0]

  # Client API

  def start_link(n, h) do
    GenServer.start_link(__MODULE__, {n, h}, name: __MODULE__)
  end

  def wait_for_completion(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
  end

  # Server Callbacks

  @impl true
  def init({n, h}) do
    {:ok, perf} = PerfTracker.start_link()

    rings =
      [:neg, :zero, :pos_even, :pos_odd]
      |> Enum.map(fn ring_id ->
        {:ok, pid} = RingManager.start_link(ring_id, n, self())
        {ring_id, pid}
      end)
      |> Map.new()

    state = %__MODULE__{rings: rings, perf: perf, n: n, h: h}

    # Spawn stdin reader
    coordinator = self()

    spawn(fn ->
      read_stdin(coordinator)
    end)

    {:ok, state}
  end

  @impl true
  def handle_cast({:input, value}, state) do
    ring_id = Transforms.classify(value)
    ring_pid = Map.fetch!(state.rings, ring_id)

    token_id = state.token_counter + 1
    token = Token.new(token_id, ring_id, value, state.h)

    RingManager.enqueue(ring_pid, token)

    {:noreply,
     %{state | pending_count: state.pending_count + 1, token_counter: token_id}}
  end

  @impl true
  def handle_cast(:done_reading, state) do
    new_state = %{state | done_reading: true}
    maybe_shutdown(new_state)
  end

  @impl true
  def handle_info({:result, %Token{} = token}, state) do
    elapsed_us = System.monotonic_time(:microsecond) - token.start_time
    PerfTracker.record_latency(state.perf, elapsed_us)

    IO.puts(
      "Token ##{token.token_id}: input=#{token.orig_input}, ring=#{token.ring_id}, " <>
        "result=#{token.current_val}, hops=#{state.h}, latency=#{elapsed_us}us"
    )

    new_state = %{state | pending_count: state.pending_count - 1}
    maybe_shutdown(new_state)
  end

  defp maybe_shutdown(%{done_reading: true, pending_count: 0} = state) do
    PerfTracker.print_summary(state.perf)

    Enum.each(state.rings, fn {_id, pid} ->
      RingManager.shutdown(pid)
    end)

    {:stop, :normal, state}
  end

  defp maybe_shutdown(state) do
    {:noreply, state}
  end

  defp read_stdin(coordinator) do
    case IO.gets("") do
      :eof ->
        GenServer.cast(coordinator, :done_reading)

      {:error, _} ->
        GenServer.cast(coordinator, :done_reading)

      line ->
        line = String.trim(line)

        cond do
          line == "done" ->
            GenServer.cast(coordinator, :done_reading)

          line == "" ->
            read_stdin(coordinator)

          true ->
            case Integer.parse(line) do
              {value, _} ->
                GenServer.cast(coordinator, {:input, value})
                read_stdin(coordinator)

              :error ->
                IO.puts("Skipping invalid input: #{line}")
                read_stdin(coordinator)
            end
        end
    end
  end
end
