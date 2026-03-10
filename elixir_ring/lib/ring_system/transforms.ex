defmodule RingSystem.Transforms do
  @moduledoc """
  Ring-specific transformations with 64-bit signed wraparound to match Java long overflow.
  """

  import Bitwise

  @max_signed 0x7FFFFFFFFFFFFFFF
  @mask 0xFFFFFFFFFFFFFFFF

  @doc """
  Apply the transformation for the given ring type.
  """
  def apply_transform(:neg, v), do: wrap64(v * 3 + 1)
  def apply_transform(:zero, v), do: wrap64(v + 7)
  def apply_transform(:pos_even, v), do: wrap64(v * 101)
  def apply_transform(:pos_odd, v), do: wrap64(v * 101 + 1)

  @doc """
  Classify an integer into a ring type.
  """
  def classify(x) when x < 0, do: :neg
  def classify(0), do: :zero
  def classify(x) when rem(x, 2) == 0, do: :pos_even
  def classify(_x), do: :pos_odd

  @doc """
  Wrap an arbitrary-precision Elixir integer to behave like Java's 64-bit signed long.
  """
  def wrap64(val) do
    masked = band(val, @mask)

    if masked > @max_signed do
      masked - (@mask + 1)
    else
      masked
    end
  end
end
