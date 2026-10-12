#!/usr/bin/env python3
"""Differential test: replay random key sequences on the system Calculate.framework
(Tools/Oracle) and on DecCalc's `calc`, and report every field that differs.

Usage: difftest.py [--cases N] [--seed S] [--mode infix|rpn|both] [--show K]
                   [--min-len N] [--max-len N] [--field F ...]
"""
import argparse
import collections
import random
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ORACLE = ROOT / "Tools/Oracle/.build/oracle"
CALC = ROOT / ".build/release/calc"

DIGITS = [f"digit{i}" for i in range(10)]
BINARY = ["add", "subtract", "multiply", "divide", "power"]
UNARY = ["square", "cube", "reciprocal", "factorial", "squareRoot", "cubeRoot",
         "exponentialBaseEuler", "exponentialBase10", "exponentialBase2",
         "logarithmNatural", "logarithmBase10", "logarithmBase2",
         "sine", "cosine", "tangent", "inverseSine", "inverseCosine", "inverseTangent",
         "hyperbolicSine", "hyperbolicCosine", "hyperbolicTangent",
         "inverseHyperbolicSine", "inverseHyperbolicCosine", "inverseHyperbolicTangent"]
PARAMETERIZED = ["root", "logarithmBaseCustom", "exponentialBaseCustom"]
EDIT = ["clear", "delete", "negate", "percent", "equals", "allClear"]
CONSTANTS = ["pi", "eulerNumber", "ee", "decimal"]
PARENS = ["openParenthesis", "closeParenthesis"]
STACK = ["enter", "swap", "drop", "rollIn", "rollOut"]


TYPICAL_FUNCTIONS = ["square", "squareRoot", "reciprocal", "sine", "cosine", "logarithmBase10",
                     "logarithmNatural", "factorial", "pi", "exponentialBaseEuler"]


def typical_keys(rng, mode, min_len, max_len):
    """Everyday use: mostly numbers and the four operations."""
    keys = []
    for _ in range(rng.randint(min_len, max_len)):
        r = rng.random()
        if r < 0.58:
            keys.append(rng.choice(DIGITS))
        elif r < 0.63:
            keys.append("decimal")
        elif r < 0.80:
            keys.append(rng.choice(["add", "subtract", "multiply", "divide"]))
        elif r < 0.86:
            keys.append("equals" if mode == "infix" else "enter")
        elif r < 0.93:
            keys.append(rng.choice(TYPICAL_FUNCTIONS))
        else:
            keys.append(rng.choice(["clear", "delete", "negate", "percent"]))
    return keys


def random_keys(rng, mode, min_len=2, max_len=12):
    keys = []
    for _ in range(rng.randint(min_len, max_len)):
        r = rng.random()
        if r < 0.45:
            keys.append(rng.choice(DIGITS))
        elif r < 0.62:
            keys.append(rng.choice(BINARY))
        elif r < 0.74:
            keys.append(rng.choice(UNARY))
        elif r < 0.78:
            keys.append(rng.choice(PARAMETERIZED))
        elif r < 0.85:
            keys.append(rng.choice(EDIT))
        elif r < 0.91:
            keys.append(rng.choice(CONSTANTS))
        elif mode == "infix":
            keys.append(rng.choice(PARENS))
        else:
            keys.append(rng.choice(STACK))
    return keys


def run(binary, lines):
    out = subprocess.run([str(binary)], input="\n".join(lines) + "\n",
                         capture_output=True, text=True, check=True).stdout
    return out.splitlines()


def fields(line):
    parts = line.split("\t")
    return {p.split("=", 1)[0]: p.split("=", 1)[1] for p in parts[2:] if "=" in p}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cases", type=int, default=2000)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--mode", default="both")
    ap.add_argument("--show", type=int, default=3, help="examples per mismatch category")
    ap.add_argument("--field", action="append", help="only compare these fields")
    ap.add_argument("--profile", choices=["random", "typical"], default="random")
    ap.add_argument("--min-len", type=int, default=2)
    ap.add_argument("--same-plain", action="store_true",
                    help="only score cases whose expression text matches (isolates evaluation and display)")
    ap.add_argument("--max-len", type=int, default=12)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    modes = ["infix", "rpn"] if args.mode == "both" else [args.mode]
    cases = []
    for i in range(args.cases):
        mode = modes[i % len(modes)]
        degrees = rng.choice(["0", "1"])
        fmt = "0" if mode == "infix" else "2"
        cases.append(f"K {fmt} {degrees} " + " ".join((typical_keys if args.profile == "typical" else random_keys)(rng, mode, args.min_len, args.max_len)))

    expected = run(ORACLE, cases)
    actual = run(CALC, cases)
    assert len(expected) == len(actual) == len(cases), (len(expected), len(actual), len(cases))

    compared = args.field or ["plain", "value", "shown", "stack"]
    mismatches = collections.defaultdict(list)
    failed_cases = 0
    skipped = 0
    for case, e, a in zip(cases, expected, actual):
        fe, fa = fields(e), fields(a)
        if args.same_plain and fe.get("plain") != fa.get("plain"):
            skipped += 1
            continue
        bad = [f for f in compared if f in fe and fe.get(f) != fa.get(f)]
        if bad:
            failed_cases += 1
            mismatches[bad[0]].append((case, fe, fa))

    total = len(cases) - skipped
    if skipped:
        print(f"(skipped {skipped} cases whose expression text differs)")
    print(f"{total - failed_cases}/{total} cases match ({100 * (total - failed_cases) / total:.1f}%)")
    for field, items in sorted(mismatches.items(), key=lambda kv: -len(kv[1])):
        print(f"\n== first mismatch in '{field}': {len(items)} cases")
        for case, fe, fa in items[:args.show]:
            print(f"  {case}")
            for f in compared:
                if f in fe and fe.get(f) != fa.get(f):
                    print(f"    {f}: oracle={fe.get(f)!r}  calc={fa.get(f)!r}")
    sys.exit(0 if failed_cases == 0 else 1)


if __name__ == "__main__":
    main()
