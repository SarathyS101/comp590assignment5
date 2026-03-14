# Performance Analysis: Elixir vs Java Ring System

## Hardware & Environment

- **Machine**: [MacBook Air M3, 16GB RAM]
- **OS**: macOS
- **Elixir**: 1.19.5 on Erlang/OTP 28
- **Java**: OpenJDK 24.0.2

## Methodology

- Fixed input set of 50 integers (seeded random, range -1,000,000 to 1,000,000)
- Parameter sweep over N (nodes per ring) and H (hops per token)
- N values: 100, 500, 1,000 (Java hangs at N >= 2,000 due to OS thread limits)
- H values: 100, 1,000, 5,000, 10,000
- Metrics: wall-clock time, per-token latency (p50), throughput (tokens/sec)

### Metrics & Monitoring Tools

Elixir used a BeamMon process to track memory usage, process count, and the run queue directly from the BEAM VM.
Java used a custom JvmMon daemon thread querying Runtime.getRuntime() and
ManagementFactory.getThreadMXBean() to track heap usage and active thread count.

## Results

### Latency (microseconds, p50) by N and H

| N \ H      | 100   | 1,000 | 5,000  | 10,000 |
|------------|-------|-------|--------|--------|
| **Elixir** |       |       |        |        |
| 100        | 1388  | 9991  | 48745  | 97611  |
| 500        | 1773  | 14909 | 59130  | 104848 |
| 1,000      | 1576  | 13053 | 61564  | 114180 |
| 2,000      | 1446  | 12462 | 66953  | 133998 |
| **Java**   |       |       |        |        |
| 100        | 20972 | 134952| 610641 | 1236652|
| 500        | 137924| 952436| 4506120| 9153068|
| 1,000      | 339410| 1968131| 9293825| 18309765|
| 2,000      | timeout| timeout| timeout| timeout|

### Throughput (tokens/sec)

| N \ H      | 100   | 1,000 | 5,000  | 10,000 |
|------------|-------|-------|--------|--------|
| **Elixir** |       |       |        |        |
| 100        | 8099.8| 2261.7| 593.7  | 294.2  |
| 500        | 6385.7| 1504.3| 446.2  | 248.4  |
| 1,000      | 4861.9| 1427.8| 414.1  | 232.7  |
| 2,000      | 3630.3| 1332.2| 365.4  | 197.7  |
| **Java**   |       |       |        |        |
| 100        | 1061.5| 188.4 | 41.6   | 21.9   |
| 500        | 231.3 | 29.1  | 6.1    | 3.0    |
| 1,000      | 105.0 | 14.4  | 3.0    | 1.5    |
| 2,000      | timeout| timeout| timeout| timeout|

*Tables auto-populated by `./scripts/benchmark.sh`.*

## Analysis

### Expected Observations

1. **Small N, large H**: Token spends most time hopping through a small ring. Elixir's lightweight process messaging should excel here due to low per-message overhead.

2. **Large N, small H**: Many nodes spawned but few hops. Startup cost dominates. Java thread creation is expensive; Elixir process creation is nearly free.

3. **Large N, large H**: Stress test. Elixir may show more consistent latency due to preemptive scheduling. Java may have higher throughput per-hop due to JIT optimization of the tight transform loop.

### Actual Observations

1. Elixir won in all Scenarios: The BEAM virtual machine significantly outperformed Java in both latency and throughput across every combination of N and H. Elixir proved exceptionally well-suited for this architecture, validating that its lightweight process model and built in message-passing primitives are vastly superior to standard Java threading for high volume, small-payload concurrent messaging.
2. Java Scalability Collapse: Java exhibited catastrophic performance degradation as the number of nodes (N) increased. Moving from N=100 to N=1000 at H=10,000 caused Java's latency to balloon from  around 1.2 seconds to over 18 seconds, while Elixir's latency barely increased (from around 97ms to 114ms). 
3. Refutation of JIT Throughput Hypothesis: The expectation that Java's JIT compiler might eventually yield higher throughput at large H values (due to optimized math operations) was incorrect. The data shows that the synchronization overhead of LinkedBlockingQueue and the intense cost of OS thread context-switching completely overshadowed any pure computational advantages the JVM might have had.

### Concurrency Model Comparison

| Aspect | Elixir (BEAM) | Java (Threads) |
|--------|---------------|----------------|
| Unit of concurrency | Process (~300 bytes) | Thread (~512KB-1MB stack) |
| Scheduling | Preemptive, per-reduction | OS-level (or virtual threads) |
| Message passing | Built-in mailboxes | LinkedBlockingQueue |
| Memory scaling (N=1000) | ~1.2MB for 4K processes | ~2-4GB for 4K threads |
| Overflow handling | Explicit 64-bit masking | Native long wraparound |

### Bottleneck Analysis

- **Elixir**: At very high H, the bottleneck is the single-token-in-flight constraint per ring. The BEAM scheduler efficiently handles process switching, but serial token processing limits parallelism within a ring.

- **Java**: Thread context switching overhead grows with N. For large N, many threads compete for CPU time. The LinkedBlockingQueue introduces synchronization overhead per hop.

## Conclusions
For systems that requre thousands of concurrent, message passing entities, Elixir/OTP is the definitively better tool to use directly. If the system haas to be implemented in Java, the current architecture (1 OS Thread to 1 Node) is not viable. The Java implementation would require a fundamental rewrite utilizing Java 21+ Virtual Threads (Project Loom) or an external Actor-model framework (such as Akka) to bypass the limitations of OS-level thread mapping and achieve parity with Elixir's baseline capabilities.
