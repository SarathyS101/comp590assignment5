#!/usr/bin/env bash
# benchmark.sh - Automated parameter sweep for Elixir and Java ring systems
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ELIXIR_DIR="$ROOT/elixir_ring"
JAVA_DIR="$ROOT/java_ring"

# Generate test input: mix of negative, zero, positive even, positive odd
generate_input() {
    local count=$1
    python3 -c "
import random
random.seed(42)
for _ in range($count):
    print(random.randint(-1000000, 1000000))
print('done')
"
}

# Parameter combinations to test
N_VALUES=(100 1000 5000 10000 50000)
H_VALUES=(100 1000 10000 50000)
INPUT_COUNT=50

echo "============================================"
echo "  Ring System Benchmark"
echo "  Date: $(date)"
echo "  Input count: $INPUT_COUNT integers"
echo "============================================"
echo ""

# Build both projects
echo "Building Elixir..."
(cd "$ELIXIR_DIR" && mix escript.build 2>/dev/null)

echo "Building Java..."
(cd "$JAVA_DIR" && make 2>/dev/null)
echo ""

INPUT_FILE=$(mktemp)
generate_input $INPUT_COUNT > "$INPUT_FILE"

for n in "${N_VALUES[@]}"; do
    for h in "${H_VALUES[@]}"; do
        echo "--- N=$n, H=$h ---"

        # Elixir
        echo -n "  Elixir: "
        start=$(python3 -c "import time; print(time.time())")
        (cd "$ELIXIR_DIR" && cat "$INPUT_FILE" | ./ring_system --n "$n" --h "$h" 2>&1) | tail -6
        end=$(python3 -c "import time; print(time.time())")
        elapsed=$(python3 -c "print(f'{$end - $start:.3f}s')")
        echo "  Wall time: $elapsed"

        # Java
        echo -n "  Java: "
        start=$(python3 -c "import time; print(time.time())")
        (cd "$JAVA_DIR" && cat "$INPUT_FILE" | java -cp out ringsystem.Main --n "$n" --h "$h" 2>&1) | tail -6
        end=$(python3 -c "import time; print(time.time())")
        elapsed=$(python3 -c "print(f'{$end - $start:.3f}s')")
        echo "  Wall time: $elapsed"
        echo ""
    done
done

rm -f "$INPUT_FILE"
echo "Benchmark complete."
