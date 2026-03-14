# Group
- Sarathy Selvam (PID: 730770538)
- Lakshin Ganesha (PID: 730757493)


# Concurrent Four-Ring System in Elixir vs Java

Overview

We implemented a concurrent system composed of four independent rings of processes/threads. A central Coordinator reads integer inputs, routes them to one of four rings based on their value (Negative, Zero, Positive Even, Positive Odd), and tracks the completion of the work. Each ring circulates a token for a specified number of hops (H), applying a ring-specific mathematical transformation at each node.

The reason we used the two languages in this assignment is to compare concurrency models. Elixir, Utilizing the BEAM virtual machine's lightweight actor-model processes. Java, Utilizing standard OS-level threads and shared memory structures

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
Each ring only takes one process at a time and queues the rest until it finished its hops. 

Java Implementation: The RingManager thread uses an ArrayDeque<Token> as a waitQueue. Uising an inFlight boolean flag. When an EnqueueCmd is received, it checks the flag. If true, the token is queued. When a token completes its final hop, it is sent back to the RingManager via a LinkedBlockingQueue. The manager reports the result to the Coordinator, pulls the next token from the waitQueue, and dispatches it to the first node.

Elixir Implementation: The queueing is naturally handled by the BEAM's built-in message mailboxes. The RingManager process maintains the state of the active token and a list of queued tokens. It pattern-matches incoming messages to manage the queue without requiring explicit locking mechanisms.

### Routing Rules
- `x < 0` → NEG ring (transform: `v * 3 + 1`)
- `x == 0` → ZERO ring (transform: `v + 7`)
- `x > 0, even` → POS_EVEN ring (transform: `v * 101`)
- `x > 0, odd` → POS_ODD ring (transform: `v * 101 + 1`)

Each token hops through H nodes in its ring. Only one token is in-flight per ring at a time (FIFO queue for waiting tokens).

In java each ringnode is a dedicated thread that continuously polls a LinkedBlockingQueue<Object> inbox. To pass a token to the next node, it places the token into the next node's queue (nextInbox.put(token)). This introduces thread safe synchronization overhead at every single hop. While in Elixir, nodes are lightweight processes. Tokens are passed using asynchronous message passing (send/2), which is highly optimized within the BEAM.

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
