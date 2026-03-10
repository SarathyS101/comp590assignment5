defmodule RingSystem.BeamMon do
  @moduledoc """
  BEAM VM monitoring. Prints memory usage, process count, and run queue length every 5 seconds.
  """

  def start do
    spawn(fn -> loop() end)
  end

  defp loop do
    memory = :erlang.memory()
    process_count = :erlang.system_info(:process_count)
    run_queue = :erlang.statistics(:run_queue)

    IO.puts(
      "[BeamMon] processes=#{process_count}, " <>
        "memory_total=#{div(memory[:total], 1024)}KB, " <>
        "memory_processes=#{div(memory[:processes], 1024)}KB, " <>
        "run_queue=#{run_queue}"
    )

    Process.sleep(5_000)
    loop()
  end
end
