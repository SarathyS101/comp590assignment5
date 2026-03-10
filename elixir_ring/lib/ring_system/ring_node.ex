defmodule RingSystem.RingNode do
  @moduledoc """
  A lightweight process that forms one node of a ring.
  Receives tokens, applies a transformation, and forwards to the next node.
  """

  alias RingSystem.{Token, Transforms}

  def start(ring_id, manager_pid) do
    spawn(fn -> init(ring_id, manager_pid) end)
  end

  defp init(ring_id, manager_pid) do
    receive do
      {:set_next, next_pid} ->
        loop(ring_id, manager_pid, next_pid)
    end
  end

  defp loop(ring_id, manager_pid, next_pid) do
    receive do
      {:token, %Token{remaining_hops: 0} = token} ->
        send(manager_pid, {:token_complete, token})
        loop(ring_id, manager_pid, next_pid)

      {:token, %Token{} = token} ->
        new_val = Transforms.apply_transform(ring_id, token.current_val)

        updated = %Token{
          token
          | current_val: new_val,
            remaining_hops: token.remaining_hops - 1
        }

        send(next_pid, {:token, updated})
        loop(ring_id, manager_pid, next_pid)

      :shutdown ->
        :ok
    end
  end
end
