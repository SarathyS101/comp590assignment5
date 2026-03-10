defmodule RingSystem.CLI do
  @moduledoc """
  Escript entry point. Parses --n and --h arguments and starts the ring system.
  """

  def main(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [n: :integer, h: :integer])

    n = Keyword.get(opts, :n, 10)
    h = Keyword.get(opts, :h, 10)

    IO.puts("Starting ring system with N=#{n} nodes per ring, H=#{h} hops per token")
    IO.puts("Enter integers (one per line). Type 'done' or EOF to finish.\n")

    RingSystem.BeamMon.start()

    {:ok, pid} = RingSystem.Coordinator.start_link(n, h)
    RingSystem.Coordinator.wait_for_completion(pid)
  end
end
