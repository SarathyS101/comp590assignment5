#!/usr/bin/env bash
# benchmark_n2000.sh - Runs only N=2000 row (Elixir only, Java hangs at this size)
# Updates ANALYSIS.md incrementally after each H value
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ELIXIR_DIR="$ROOT/elixir_ring"
JAVA_DIR="$ROOT/java_ring"
ANALYSIS="$ROOT/ANALYSIS.md"

N=2000
H_VALUES=(100 1000 5000 10000)
INPUT_COUNT=50

# Generate test input
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

# Update a single cell in ANALYSIS.md for the 2,000 row
# Usage: update_cell <lang> <h> <p50> <throughput>
update_cell() {
    local lang=$1 h=$2 p50=$3 throughput=$4
    python3 - "$lang" "$h" "$p50" "$throughput" "$ANALYSIS" <<'PYEOF'
import sys, re

lang, h, p50, throughput, analysis_file = sys.argv[1:]
h = int(h)

h_values = [100, 1000, 5000, 10000]
col_idx = h_values.index(h)

with open(analysis_file) as f:
    content = f.read()

for section, value in [("Latency", p50), ("Throughput", throughput)]:
    if section == "Latency":
        pattern = r"### Latency \(microseconds, p50\) by N and H\n"
    else:
        pattern = r"### Throughput \(tokens/sec\)\n"

    match = re.search(pattern, content)
    if not match:
        continue
    table_start = match.end()

    lang_label = "Elixir" if lang == "elixir" else "Java"
    lang_pattern = re.compile(r"^\| \*\*" + lang_label + r"\*\*", re.MULTILINE)
    lang_match = lang_pattern.search(content, table_start)
    if not lang_match:
        continue

    row_start = lang_match.end()
    row_pattern = re.compile(r"^\| 2,000\s+\|", re.MULTILINE)
    row_match = row_pattern.search(content, row_start)
    if not row_match:
        continue

    row_end = content.index("\n", row_match.start())
    old_row = content[row_match.start():row_end]

    cells = [c.strip() for c in old_row.split("|")]
    cell_idx = col_idx + 2
    cells[cell_idx] = value

    new_row = f"| {cells[1]}".ljust(13)
    for i in range(2, 6):
        w = 6 if i < 4 else 7
        new_row += "| " + cells[i].ljust(w)
    new_row += "|"

    content = content[:row_match.start()] + new_row + content[row_end:]

with open(analysis_file, "w") as f:
    f.write(content)
PYEOF
}

echo "=== Benchmark N=$N (Elixir + Java) ==="
echo ""

# Build
echo "Building Elixir..."
(cd "$ELIXIR_DIR" && mix escript.build 2>/dev/null)
echo "Building Java..."
(cd "$JAVA_DIR" && make 2>/dev/null)
echo ""

INPUT_FILE=$(mktemp)
generate_input $INPUT_COUNT > "$INPUT_FILE"

for h in "${H_VALUES[@]}"; do
    echo "--- N=$N, H=$h ---"

    # Elixir
    echo -n "  Elixir: "
    start=$(python3 -c "import time; print(time.time())")
    output=$( (cd "$ELIXIR_DIR" && cat "$INPUT_FILE" | ./ring_system --n "$N" --h "$h" 2>&1) || true )
    end=$(python3 -c "import time; print(time.time())")
    elapsed=$(python3 -c "print(f'{$end - $start:.3f}s')")
    echo "$output" | tail -6
    echo "  Wall time: $elapsed"

    p50=$(echo "$output" | python3 -c "import sys,re; m=re.search(r'p50=(\d+)',sys.stdin.read()); print(m.group(1) if m else 'N/A')")
    throughput=$(echo "$output" | python3 -c "import sys,re; m=re.search(r'Throughput: ([\d.]+)',sys.stdin.read()); print(m.group(1) if m else 'N/A')")
    update_cell elixir "$h" "$p50" "$throughput"
    echo "  >> Updated ANALYSIS.md (Elixir N=$N H=$h)"

    # Java (may be slow/hang — 60s timeout, kills entire process group)
    echo -n "  Java: "
    start=$(python3 -c "import time; print(time.time())")
    JAVA_OUT=$(mktemp)
    ( cd "$JAVA_DIR" && cat "$INPUT_FILE" | java -cp out ringsystem.Main --n "$N" --h "$h" 2>&1 ) > "$JAVA_OUT" &
    java_pid=$!
    ( sleep 60 && kill -9 $java_pid 2>/dev/null ) &
    watchdog_pid=$!
    wait $java_pid 2>/dev/null
    java_exit=$?
    kill $watchdog_pid 2>/dev/null
    wait $watchdog_pid 2>/dev/null
    output=$(cat "$JAVA_OUT")
    rm -f "$JAVA_OUT"
    end=$(python3 -c "import time; print(time.time())")
    elapsed=$(python3 -c "print(f'{$end - $start:.3f}s')")

    if [ $java_exit -eq 137 ] || [ -z "$output" ] || ! echo "$output" | grep -q "PerfTracker.*p50"; then
        echo "  TIMED OUT or no results (60s limit, wall=$elapsed)"
        p50="timeout"
        throughput="timeout"
    else
        echo "$output" | tail -6
        echo "  Wall time: $elapsed"
        p50=$(echo "$output" | python3 -c "import sys,re; m=re.search(r'p50=(\d+)',sys.stdin.read()); print(m.group(1) if m else 'N/A')")
        throughput=$(echo "$output" | python3 -c "import sys,re; m=re.search(r'Throughput: ([\d.]+)',sys.stdin.read()); print(m.group(1) if m else 'N/A')")
    fi
    update_cell java "$h" "$p50" "$throughput"
    echo "  >> Updated ANALYSIS.md (Java N=$N H=$h)"

    echo ""
done

rm -f "$INPUT_FILE"
echo "Done."
