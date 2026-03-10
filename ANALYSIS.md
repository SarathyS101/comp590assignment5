# Performance Analysis: Elixir vs Java Ring System

## Hardware & Environment

- **Machine**: [Fill in: e.g., MacBook Pro M2, 16GB RAM]
- **OS**: macOS
- **Elixir**: 1.19.5 on Erlang/OTP 28
- **Java**: OpenJDK 24.0.2

## Methodology

- Fixed input set of 50 integers (seeded random, range -1,000,000 to 1,000,000)
- Parameter sweep over N (nodes per ring) and H (hops per token)
- Each configuration run 3 times, median reported
- Metrics: wall-clock time, per-token latency (p50, p95), throughput (tokens/sec)

## Results

### Latency (microseconds, p50) by N and H

| N \ H      | 100   | 1,000 | 10,000 | 50,000 |
|------------|-------|-------|--------|--------|
| **Elixir** |       |       |        |        |
| 100        |       |       |        |        |
| 1,000      |       |       |        |        |
| 5,000      |       |       |        |        |
| 10,000     |       |       |        |        |
| 50,000     |       |       |        |        |
| **Java**   |       |       |        |        |
| 100        |       |       |        |        |
| 1,000      |       |       |        |        |
| 5,000      |       |       |        |        |
| 10,000     |       |       |        |        |
| 50,000     |       |       |        |        |

### Throughput (tokens/sec)

| N \ H      | 100   | 1,000 | 10,000 | 50,000 |
|------------|-------|-------|--------|--------|
| **Elixir** |       |       |        |        |
| 100        |       |       |        |        |
| 1,000      |       |       |        |        |
| 5,000      |       |       |        |        |
| 10,000     |       |       |        |        |
| 50,000     |       |       |        |        |
| **Java**   |       |       |        |        |
| 100        |       |       |        |        |
| 1,000      |       |       |        |        |
| 5,000      |       |       |        |        |
| 10,000     |       |       |        |        |
| 50,000     |       |       |        |        |

*Run `./scripts/benchmark.sh` and fill in the tables above.*

## Analysis

### Expected Observations

1. **Small N, large H**: Token spends most time hopping through a small ring. Elixir's lightweight process messaging should excel here due to low per-message overhead.

2. **Large N, small H**: Many nodes spawned but few hops. Startup cost dominates. Java thread creation is expensive; Elixir process creation is nearly free.

3. **Large N, large H**: Stress test. Elixir may show more consistent latency due to preemptive scheduling. Java may have higher throughput per-hop due to JIT optimization of the tight transform loop.

### Concurrency Model Comparison

| Aspect | Elixir (BEAM) | Java (Threads) |
|--------|---------------|----------------|
| Unit of concurrency | Process (~300 bytes) | Thread (~512KB-1MB stack) |
| Scheduling | Preemptive, per-reduction | OS-level (or virtual threads) |
| Message passing | Built-in mailboxes | LinkedBlockingQueue |
| Memory scaling (N=50000) | ~60MB for 200K processes | ~100GB for 200K threads (impractical) |
| Overflow handling | Explicit 64-bit masking | Native long wraparound |

### Bottleneck Analysis

- **Elixir**: At very high H, the bottleneck is the single-token-in-flight constraint per ring. The BEAM scheduler efficiently handles process switching, but serial token processing limits parallelism within a ring.

- **Java**: Thread context switching overhead grows with N. For large N, many threads compete for CPU time. The LinkedBlockingQueue introduces synchronization overhead per hop.

## Conclusions

*Fill in after running benchmarks.*
