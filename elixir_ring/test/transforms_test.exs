defmodule RingSystem.TransformsTest do
  use ExUnit.Case, async: true

  alias RingSystem.Transforms

  test "classify negative" do
    assert Transforms.classify(-5) == :neg
    assert Transforms.classify(-1) == :neg
  end

  test "classify zero" do
    assert Transforms.classify(0) == :zero
  end

  test "classify positive even" do
    assert Transforms.classify(2) == :pos_even
    assert Transforms.classify(100) == :pos_even
  end

  test "classify positive odd" do
    assert Transforms.classify(1) == :pos_odd
    assert Transforms.classify(99) == :pos_odd
  end

  test "neg transform: v * 3 + 1" do
    assert Transforms.apply_transform(:neg, -5) == -14
    assert Transforms.apply_transform(:neg, 10) == 31
  end

  test "zero transform: v + 7" do
    assert Transforms.apply_transform(:zero, 0) == 7
    assert Transforms.apply_transform(:zero, 100) == 107
  end

  test "pos_even transform: v * 101" do
    assert Transforms.apply_transform(:pos_even, 2) == 202
    assert Transforms.apply_transform(:pos_even, 100) == 10100
  end

  test "pos_odd transform: v * 101 + 1" do
    assert Transforms.apply_transform(:pos_odd, 1) == 102
    assert Transforms.apply_transform(:pos_odd, 99) == 10000
  end

  test "64-bit wraparound matches Java long" do
    large = 0x7FFFFFFFFFFFFFFF
    # NEG: (2^63-1) * 3 + 1 = 3*2^63 - 3 + 1 = 3*2^63 - 2
    # mod 2^64: 2^64 + 2^63 - 2 mod 2^64 = 2^63 - 2 (positive, fits in signed)
    result = Transforms.apply_transform(:neg, large)
    assert result == 9223372036854775806

    # wrap64 edge cases that produce negative values
    assert Transforms.wrap64(0x8000000000000000) == -9223372036854775808
    assert Transforms.wrap64(0xFFFFFFFFFFFFFFFF) == -1
    assert Transforms.wrap64(0x10000000000000000) == 0
  end

  test "wrap64 basic" do
    assert Transforms.wrap64(0) == 0
    assert Transforms.wrap64(1) == 1
    assert Transforms.wrap64(-1) == -1
    assert Transforms.wrap64(0x7FFFFFFFFFFFFFFF) == 0x7FFFFFFFFFFFFFFF
  end
end
