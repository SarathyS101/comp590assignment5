defmodule RingSystem.RingManager do
  @moduledoc """
  GenServer managing a single ring of N nodes.
  Maintains a FIFO queue and enforces single-token-in-flight.
  """

  use GenServer

  alias RingSystem.{RingNode, Token}

  defstruct [:ring_id, :coordinator, :nodes, :entry_node, queue: :queue.new(), in_flight: false]

  # Client API

  def start_link(ring_id, n, coordinator) do
    GenServer.start_link(__MODULE__, {ring_id, n, coordinator})
  end

  def enqueue(pid, %Token{} = token) do
    GenServer.cast(pid, {:enqueue, token})
  end

  def shutdown(pid) do
    GenServer.cast(pid, :shutdown)
  end

  # Server Callbacks

  @impl true
  def init({ring_id, n, coordinator}) do
    nodes = for _ <- 1..n, do: RingNode.start(ring_id, self())

    # Wire nodes in a directed cycle
    nodes
    |> Enum.zip(Enum.drop(nodes, 1) ++ [hd(nodes)])
    |> Enum.each(fn {node, next} -> send(node, {:set_next, next}) end)

    state = %__MODULE__{
      ring_id: ring_id,
      coordinator: coordinator,
      nodes: nodes,
      entry_node: hd(nodes)
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:enqueue, token}, state) do
    if state.in_flight do
      {:noreply, %{state | queue: :queue.in(token, state.queue)}}
    else
      dispatch(token, state)
      {:noreply, %{state | in_flight: true}}
    end
  end

  @impl true
  def handle_cast(:shutdown, state) do
    Enum.each(state.nodes, fn pid -> send(pid, :shutdown) end)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:token_complete, token}, state) do
    send(state.coordinator, {:result, token})

    case :queue.out(state.queue) do
      {{:value, next_token}, new_queue} ->
        dispatch(next_token, state)
        {:noreply, %{state | queue: new_queue}}

      {:empty, _} ->
        {:noreply, %{state | in_flight: false}}
    end
  end

  defp dispatch(%Token{} = token, state) do
    send(state.entry_node, {:token, token})
  end
end
