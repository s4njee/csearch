#!/usr/bin/env python3
"""Blue/green retrieval parity harness (V2 refactor Phase 4).

Runs identical semantic queries against BLUE (netcup, v1 nlp tables) and
GREEN (freya csearch-v2, v2 corpus via compat views) and reports:

  * structural metrics per side (bills, chunks, per-bill distribution)
  * top-10 retrieved-bill overlap per query + mean overlap@10
  * per-side query latency (pod-local psql \\timing: server + local overhead)

Overlap needs no gold labels — the question is whether green retrieves the
same bills blue does, not whether either is "right" (that's the eval set's
job). Differences concentrate where the corpora deliberately differ:
cap-200 enforcement on mega-bills (see docs/V2-REFACTOR-PLAN.md Phase 3).

Usage:
    OPENAI_API_KEY=... python3 scripts/parity-harness.py \
        [--top-k 10] [--candidates 50] [--report docs/PARITY-<date>.md]
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import statistics
import subprocess
import sys
import urllib.request

MODEL = "text-embedding-3-small"
DIMS = 1536

QUERIES = [
    # the eval set's one non-fixture query, plus curated cross-domain topics
    "lowering the cost of prescription drugs for seniors",
    "expanding rural broadband internet access",
    "offshore wind energy permitting reform",
    "border security and asylum processing",
    "veterans mental health care services",
    "artificial intelligence safety and regulation",
    "childhood nutrition and school lunch programs",
    "semiconductor manufacturing incentives",
    "protecting elections from foreign interference",
    "wildfire prevention and forest management",
    "student loan forgiveness programs",
    "restricting PFAS chemicals in drinking water",
]

BLUE = {
    "name": "blue (netcup v1)",
    "kubectl": ["kubectl", "--context", "netcup", "exec", "-i", "postgres-0",
                "-c", "postgres", "--"],
    "schema": "nlp",
}
GREEN = {
    "name": "green (freya v2)",
    "kubectl": ["kubectl", "--context", "freya", "-n", "csearch-v2", "exec", "-i",
                "postgres-0", "-c", "postgres", "--"],
    "schema": "nlp_stage",   # pre-swap; post-swap this becomes nlp
}


def psql(side: dict, sql: str, timing: bool = False) -> str:
    cmd = side["kubectl"] + [
        "sh", "-c",
        'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -qtA'
        + (' -c "\\timing on"' if timing else "")]
    # SQL over stdin: vector literals are ~12KB, too big for argv comfort
    proc = subprocess.run(side["kubectl"] + ["sh", "-c",
        'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -qtAF"|"'
        + (" -c '\\timing on' -f -" if timing else " -f -")],
        input=sql.encode(), capture_output=True, timeout=300)
    if proc.returncode != 0:
        raise RuntimeError(f"{side['name']} psql failed: {proc.stderr.decode()[-400:]}")
    out = proc.stdout.decode()
    return "\n".join(l for l in out.splitlines()
                     if not re.match(r"^(WARNING|DETAIL|HINT|NOTICE)", l))


def embed(queries: list[str], api_key: str) -> list[list[float]]:
    req = urllib.request.Request(
        "https://api.openai.com/v1/embeddings",
        data=json.dumps({"model": MODEL, "input": queries, "dimensions": DIMS}).encode(),
        headers={"Authorization": f"Bearer {api_key}",
                 "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.load(r)
    return [d["embedding"] for d in sorted(data["data"], key=lambda d: d["index"])]


def structure(side: dict) -> dict:
    s = side["schema"]
    out = psql(side, f"""
        SELECT count(DISTINCT canonical_bill_id) || '|' || count(*) FROM {s}.bill_chunks WHERE congress=119;
        SELECT round(avg(n),1) || '|' || percentile_disc(0.95) WITHIN GROUP (ORDER BY n) || '|' || max(n)
          FROM (SELECT count(*) n FROM {s}.bill_chunks WHERE congress=119 GROUP BY canonical_bill_id) t;
    """)
    lines = [l for l in out.splitlines() if l.strip()]
    bills, chunks = lines[0].split("|")
    avg, p95, mx = lines[1].split("|")
    return {"bills": int(bills), "chunks": int(chunks),
            "per_bill_avg": float(avg), "per_bill_p95": int(p95), "per_bill_max": int(mx)}


def top_bills(side: dict, vec: list[float], top_k: int, candidates: int) -> tuple[list[tuple[str, float]], float]:
    s = side["schema"]
    lit = "[" + ",".join(f"{v:.7g}" for v in vec) + "]"
    sql = f"""
WITH tk AS (
    SELECT chunk_id, 1 - (embedding <=> '{lit}'::vector) AS sim
    FROM {s}.bill_embeddings
    WHERE model = '{MODEL}'
    ORDER BY embedding <=> '{lit}'::vector
    LIMIT {candidates}
), ranked AS (
    -- congress filter on BOTH sides: blue spans 93..119, green holds 119 only;
    -- parity is only meaningful on the shared slice
    SELECT DISTINCT ON (c.canonical_bill_id) c.canonical_bill_id AS bill, tk.sim
    FROM tk JOIN {s}.bill_chunks c ON c.id = tk.chunk_id
    WHERE c.congress = 119
    ORDER BY c.canonical_bill_id, tk.sim DESC
)
SELECT bill || '|' || round(sim::numeric, 4) FROM ranked ORDER BY sim DESC LIMIT {top_k};
"""
    out = psql(side, sql, timing=True)
    ms = 0.0
    rows = []
    for line in out.splitlines():
        m = re.match(r"^Time: ([0-9.]+) ms", line)
        if m:
            ms = max(ms, float(m.group(1)))   # the query's own time (last/biggest)
        elif "|" in line:
            bill, sim = line.rsplit("|", 1)
            rows.append((bill, float(sim)))
    return rows, ms


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--top-k", type=int, default=10)
    ap.add_argument("--candidates", type=int, default=800)
    ap.add_argument("--report", default=None)
    args = ap.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("OPENAI_API_KEY required (query embeddings)", file=sys.stderr)
        return 2

    print(f"embedding {len(QUERIES)} parity queries...")
    vecs = embed(QUERIES, api_key)

    print("structural metrics...")
    stru = {side["name"]: structure(side) for side in (BLUE, GREEN)}

    rows = []
    overlaps, lat_blue, lat_green = [], [], []
    for q, v in zip(QUERIES, vecs):
        b, bms = top_bills(BLUE, v, args.top_k, args.candidates)
        g, gms = top_bills(GREEN, v, args.top_k, args.candidates)
        bset, gset = {x[0] for x in b}, {x[0] for x in g}
        ov = len(bset & gset) / max(len(bset), 1)
        overlaps.append(ov); lat_blue.append(bms); lat_green.append(gms)
        rows.append({"query": q, "overlap": ov,
                     "blue_only": sorted(bset - gset), "green_only": sorted(gset - bset),
                     "blue_ms": bms, "green_ms": gms})
        print(f"  overlap@{args.top_k} {ov:.0%}  blue {bms:6.1f}ms  green {gms:6.1f}ms  | {q}")

    mean_ov = statistics.mean(overlaps)
    print(f"\nMEAN overlap@{args.top_k}: {mean_ov:.1%}   "
          f"latency median blue {statistics.median(lat_blue):.0f}ms / green {statistics.median(lat_green):.0f}ms")

    report = args.report or f"docs/PARITY-{datetime.date.today().isoformat()}.md"
    with open(report, "w") as f:
        f.write(f"# Blue/green retrieval parity — {datetime.date.today().isoformat()}\n\n")
        f.write("Phase 4 of docs/V2-REFACTOR-PLAN.md. Identical queries against "
                "netcup v1 (blue) and freya-v2 (green, converged corpus).\n\n")
        f.write("## Structure (congress 119)\n\n")
        f.write("| side | bills | chunks | per-bill avg | p95 | max |\n|---|---|---|---|---|---|\n")
        for name, s in stru.items():
            f.write(f"| {name} | {s['bills']} | {s['chunks']} | {s['per_bill_avg']} | {s['per_bill_p95']} | {s['per_bill_max']} |\n")
        f.write(f"\n## Retrieval overlap@{args.top_k} (mean **{mean_ov:.1%}**)\n\n")
        f.write("| overlap | blue ms | green ms | query | divergent bills (blue-only / green-only) |\n|---|---|---|---|---|\n")
        for r in rows:
            div = f"{','.join(r['blue_only']) or '—'} / {','.join(r['green_only']) or '—'}"
            f.write(f"| {r['overlap']:.0%} | {r['blue_ms']:.0f} | {r['green_ms']:.0f} | {r['query']} | {div} |\n")
        f.write(f"\nLatency medians: blue {statistics.median(lat_blue):.0f}ms, "
                f"green {statistics.median(lat_green):.0f}ms (pod-local psql timing).\n")
        f.write("\nThreshold from the plan: mean overlap@10 >= 0.9. "
                f"Result: **{'PASS' if mean_ov >= 0.9 else 'REVIEW'}**.\n")
    print(f"report written: {report}")
    return 0 if mean_ov >= 0.9 else 1


if __name__ == "__main__":
    sys.exit(main())
