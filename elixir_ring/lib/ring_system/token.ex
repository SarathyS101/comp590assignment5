defmodule RingSystem.Token do
  @moduledoc """
  Token struct that travels through ring nodes.
  """

  defstruct [
    :token_id,
    :ring_id,
    :orig_input,
    :current_val,
    :remaining_hops,
    :start_time
  ]

  @type t :: %__MODULE__{
          token_id: non_neg_integer(),
          ring_id: atom(),
          orig_input: integer(),
          current_val: integer(),
          remaining_hops: non_neg_integer(),
          start_time: integer()
        }

  def new(token_id, ring_id, value, hops) do
    %__MODULE__{
      token_id: token_id,
      ring_id: ring_id,
      orig_input: value,
      current_val: value,
      remaining_hops: hops,
      start_time: System.monotonic_time(:microsecond)
    }
  end
end
