defmodule RingSystem.PerfTracker do
  @moduledoc """
  Collects per-token latencies and computes summary statistics.
  """

  use Agent

  def start_link do
    Agent.start_link(fn ->
      %{latencies: [], start_time: System.monotonic_time(:microsecond)}
    end)
  end

  def record_latency(pid, latency_us) do
    Agent.update(pid, fn state ->
      %{state | latencies: [latency_us | state.latencies]}
    end)
  end

  def print_summary(pid) do
    state = Agent.get(pid, & &1)
    latencies = Enum.sort(state.latencies)
    count = length(latencies)

    if count == 0 do
      IO.puts("\n[PerfTracker] No tokens processed.")
    else
      elapsed_us = System.monotonic_time(:microsecond) - state.start_time
      elapsed_s = elapsed_us / 1_000_000

      min_lat = hd(latencies)
      max_lat = List.last(latencies)
      avg_lat = Enum.sum(latencies) / count
      p50 = percentile(latencies, count, 50)
      p95 = percentile(latencies, count, 95)
      throughput = count / elapsed_s

      IO.puts("\n[PerfTracker] === Performance Summary ===")
      IO.puts("[PerfTracker] Tokens processed: #{count}")
      IO.puts("[PerfTracker] Elapsed time: #{Float.round(elapsed_s, 3)}s")
      IO.puts("[PerfTracker] Throughput: #{Float.round(throughput, 1)} tokens/sec")
      IO.puts("[PerfTracker] Latency (us): min=#{min_lat}, max=#{max_lat}, avg=#{round(avg_lat)}")
      IO.puts("[PerfTracker] Latency (us): p50=#{p50}, p95=#{p95}")
    end
  end

  defp percentile(sorted, count, p) do
    idx = max(0, round(count * p / 100) - 1)
    Enum.at(sorted, idx)
  end
end
