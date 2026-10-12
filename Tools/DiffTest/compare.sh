#!/bin/sh
# Print oracle and calc results side by side for readable cases (see keys.py).
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cases=$(python3 -I "$ROOT/Tools/DiffTest/keys.py" "$@")
paste <(echo "$cases" | "$ROOT/Tools/Oracle/.build/oracle" | cut -f3-5) \
      <(echo "$cases" | "$ROOT/.build/release/calc" | cut -f4-5) | column -t -s "$(printf '\t')"
