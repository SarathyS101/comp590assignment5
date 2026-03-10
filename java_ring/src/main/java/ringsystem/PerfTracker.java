package ringsystem;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class PerfTracker {
    private final List<Long> latencies = Collections.synchronizedList(new ArrayList<>());
    private final long startTimeNanos = System.nanoTime();

    public void recordLatency(long latencyUs) {
        latencies.add(latencyUs);
    }

    public void printSummary() {
        List<Long> sorted;
        synchronized (latencies) {
            sorted = new ArrayList<>(latencies);
        }
        Collections.sort(sorted);
        int count = sorted.size();

        if (count == 0) {
            System.out.println("\n[PerfTracker] No tokens processed.");
            return;
        }

        long elapsedUs = (System.nanoTime() - startTimeNanos) / 1000;
        double elapsedS = elapsedUs / 1_000_000.0;

        long min = sorted.get(0);
        long max = sorted.get(count - 1);
        long sum = sorted.stream().mapToLong(Long::longValue).sum();
        long avg = sum / count;
        long p50 = sorted.get(Math.max(0, (int) (count * 0.50) - 1));
        long p95 = sorted.get(Math.max(0, (int) (count * 0.95) - 1));
        double throughput = count / elapsedS;

        System.out.println("\n[PerfTracker] === Performance Summary ===");
        System.out.printf("[PerfTracker] Tokens processed: %d%n", count);
        System.out.printf("[PerfTracker] Elapsed time: %.3fs%n", elapsedS);
        System.out.printf("[PerfTracker] Throughput: %.1f tokens/sec%n", throughput);
        System.out.printf("[PerfTracker] Latency (us): min=%d, max=%d, avg=%d%n", min, max, avg);
        System.out.printf("[PerfTracker] Latency (us): p50=%d, p95=%d%n", p50, p95);
    }
}
