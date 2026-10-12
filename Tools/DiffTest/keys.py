#!/usr/bin/env python3
"""Turn readable expressions into key-sequence cases for the oracle and calc.

Each argument is a whitespace-separated token list; numbers expand to digit keys:
  keys.py "2 power 10" "1.5 power -3" "100 factorial"
A leading "deg" token selects degrees; a leading "rpn" token selects RPN.
"""
import re
import sys

def number_keys(text):
    keys = []
    for c in text:
        if c.isdigit(): keys.append(f"digit{c}")
        elif c == ".": keys.append("decimal")
        elif c == "-": keys.append("subtract")
        else: raise SystemExit(f"bad number {text}")
    return keys

for case in sys.argv[1:]:
    tokens = case.split()
    fmt, deg = "0", "0"
    while tokens and tokens[0] in ("deg", "rpn"):
        if tokens[0] == "deg": deg = "1"
        else: fmt = "2"
        tokens.pop(0)
    keys = []
    for t in tokens:
        keys += number_keys(t) if re.fullmatch(r"-?[0-9.]+", t) else [t]
    print(f"K {fmt} {deg} " + " ".join(keys))
