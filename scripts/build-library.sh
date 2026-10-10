#!/bin/zsh
# Builds the bundled puzzle library. Usage: scripts/build-library.sh [count] [timeout-seconds]
# The full library (300 per file) can take hours for Expert+ Killer; run it overnight.
set -u
cd "$(dirname "$0")/.."
count=${1:-300}
timeout=${2:-600}
swift build --package-path SudokuCore -c release
forge=SudokuCore/.build/release/sudoku-forge
mkdir -p App/Library
for mode in classic killer; do
  for tier in easy medium hard expert fiendish diabolical nightmare; do
    out="App/Library/$mode-$tier.json"
    echo "== $mode $tier"
    "$forge" --mode "$mode" --tier "$tier" --count "$count" --timeout "$timeout" --out "$out" 2>&1 | tail -1
  done
done
ls -la App/Library
