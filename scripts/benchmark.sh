#!/usr/bin/env bash
# benchmark.sh - Automated parameter sweep for Elixir and Java ring systems
# Updates ANALYSIS.md incrementally after each (lang, N, H) result
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ELIXIR_DIR="$ROOT/elixir_ring"
JAVA_DIR="$ROOT/java_ring"
ANALYSIS="$ROOT/ANALYSIS.md"

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

# Update a single cell in ANALYSIS.md
# Usage: update_cell <lang> <n> <h> <p50> <throughput>
update_cell() {
    local lang=$1 n=$2 h=$3 p50=$4 throughput=$5
    python3 - "$lang" "$n" "$h" "$p50" "$throughput" "$ANALYSIS" <<'PYEOF'
import sys, re

lang, n, h, p50, throughput, analysis_file = sys.argv[1:]
n, h = int(n), int(h)

h_values = [100, 1000, 5000, 10000]
col_idx = h_values.index(h)  # 0-based column

with open(analysis_file) as f:
    content = f.read()

# Find the right table section and row for this lang/n/metric
# We need to update two tables: Latency and Throughput
for section, value in [("Latency", p50), ("Throughput", throughput)]:
    # Find the table for this section
    if section == "Latency":
        pattern = r"### Latency \(microseconds, p50\) by N and H\n"
    else:
        pattern = r"### Throughput \(tokens/sec\)\n"

    match = re.search(pattern, content)
    if not match:
        continue

    table_start = match.end()

    # Find the lang header row and then the N row after it
    lang_label = "Elixir" if lang == "elixir" else "Java"
    # Search for the lang header within this table
    lang_pattern = re.compile(r"^\| \*\*" + lang_label + r"\*\*", re.MULTILINE)
    lang_match = lang_pattern.search(content, table_start)
    if not lang_match:
        continue

    # Now find the row for this N value after the lang header
    n_fmt = f"{n:,}"
    row_start = lang_match.end()
    # Search for the row starting with | N
    row_pattern = re.compile(r"^\| " + re.escape(n_fmt) + r"\s+\|", re.MULTILINE)
    row_match = row_pattern.search(content, row_start)
    if not row_match:
        continue

    # Extract the full row
    row_end = content.index("\n", row_match.start())
    old_row = content[row_match.start():row_end]

    # Split into cells and replace the right one
    cells = [c.strip() for c in old_row.split("|")]
    # cells: ['', 'N', 'val0', 'val1', 'val2', 'val3', '']
    cell_idx = col_idx + 2  # offset for leading '' and N column
    cells[cell_idx] = value

    # Rebuild the row with padding to match table alignment
    new_row = f"| {cells[1]}".ljust(13)
    for i in range(2, 6):
        w = 6 if i < 4 else 7  # wider columns for 5,000 and 10,000
        new_row += "| " + cells[i].ljust(w)
    new_row += "|"

    content = content[:row_match.start()] + new_row + content[row_end:]

with open(analysis_file, "w") as f:
    f.write(content)
PYEOF
}

# Parameter combinations to test
# Kept manageable so Java (OS threads) can finish without hanging
N_VALUES=(100 500 1000)
H_VALUES=(100 1000 5000 10000)
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
        output=$( (cd "$ELIXIR_DIR" && cat "$INPUT_FILE" | ./ring_system --n "$n" --h "$h" 2>&1) || true )
        end=$(python3 -c "import time; print(time.time())")
        elapsed=$(python3 -c "print(f'{$end - $start:.3f}s')")
        echo "$output" | tail -6
        echo "  Wall time: $elapsed"

        p50=$(echo "$output" | python3 -c "import sys,re; m=re.search(r'p50=(\d+)',sys.stdin.read()); print(m.group(1) if m else 'N/A')")
        throughput=$(echo "$output" | python3 -c "import sys,re; m=re.search(r'Throughput: ([\d.]+)',sys.stdin.read()); print(m.group(1) if m else 'N/A')")
        update_cell elixir "$n" "$h" "$p50" "$throughput"
        echo "  >> Updated ANALYSIS.md (Elixir N=$n H=$h)"

        # Java
        echo -n "  Java: "
        start=$(python3 -c "import time; print(time.time())")
        output=$( (cd "$JAVA_DIR" && cat "$INPUT_FILE" | java -cp out ringsystem.Main --n "$n" --h "$h" 2>&1) || true )
        end=$(python3 -c "import time; print(time.time())")
        elapsed=$(python3 -c "print(f'{$end - $start:.3f}s')")
        echo "$output" | tail -6
        echo "  Wall time: $elapsed"

        p50=$(echo "$output" | python3 -c "import sys,re; m=re.search(r'p50=(\d+)',sys.stdin.read()); print(m.group(1) if m else 'N/A')")
        throughput=$(echo "$output" | python3 -c "import sys,re; m=re.search(r'Throughput: ([\d.]+)',sys.stdin.read()); print(m.group(1) if m else 'N/A')")
        update_cell java "$n" "$h" "$p50" "$throughput"
        echo "  >> Updated ANALYSIS.md (Java N=$n H=$h)"

        echo ""
    done
done

rm -f "$INPUT_FILE"
echo "Benchmark complete."
