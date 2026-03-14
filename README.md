# Group
- Sarathy Selvam (PID: 730770538)
- Lakshin Ganesha (PID: 730757493)


# Concurrent Four-Ring System

A concurrent system of four independent rings of processes/threads, implemented in both **Elixir** (BEAM processes) and **Java** (threads).

## Architecture

```
                         ┌──────────────┐
                         │  stdin input  │
                         └──────┬───────┘
                                │
                         ┌──────▼───────┐
                         │  Coordinator  │
                         │  (routing)    │
                         └──┬──┬──┬──┬──┘
                            │  │  │  │
              ┌─────────────┘  │  │  └─────────────┐
              │                │  │                 │
       ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐
       │ Ring: NEG   │ │ Ring: ZERO  │ │ Ring: P_EVEN│ │ Ring: P_ODD │
       │ (x < 0)    │ │ (x == 0)   │ │ (x>0,even) │ │ (x>0,odd)  │
       └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
              │                │                │                │
       ┌──▶N1──▶N2──▶...──▶Nn─┐  (each ring has N nodes in a cycle)
       └───────────────────────┘
```

### Routing Rules
- `x < 0` → NEG ring (transform: `v * 3 + 1`)
- `x == 0` → ZERO ring (transform: `v + 7`)
- `x > 0, even` → POS_EVEN ring (transform: `v * 101`)
- `x > 0, odd` → POS_ODD ring (transform: `v * 101 + 1`)

Each token hops through H nodes in its ring. Only one token is in-flight per ring at a time (FIFO queue for waiting tokens).

### 64-bit Arithmetic
Both implementations use 64-bit signed integer arithmetic. Java's `long` wraps naturally on overflow. Elixir uses explicit bitwise masking to match Java's behavior, ensuring identical results.

## Building & Running

### Elixir

```bash
cd elixir_ring
mix escript.build
echo -e "5\n-3\n0\n4\ndone" | ./ring_system --n 100 --h 1000
```

### Java

```bash
cd java_ring
make
echo -e "5\n-3\n0\n4\ndone" | java -cp out ringsystem.Main --n 100 --h 1000
```

### Parameters
- `--n N` — Number of nodes per ring (default: 10)
- `--h H` — Number of hops per token (default: 10)

### Input Format
- One integer per line on stdin
- Type `done` or send EOF to signal end of input
- Non-integer lines are skipped with a warning

## Benchmarking

```bash
./scripts/benchmark.sh
```

Runs both implementations across a parameter sweep of N and H values and reports latency/throughput.

## Output Format

Each completed token prints:
```
Token #1: input=5, ring=pos_odd, result=5161808, hops=3, latency=23us
```

Followed by a performance summary with min/max/avg/p50/p95 latency and throughput.

## Monitoring

- **Elixir**: BeamMon reports process count, memory usage, and run queue every 5s
- **Java**: JvmMon reports thread count and heap usage every 5s
