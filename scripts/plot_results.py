#!/usr/bin/env python3
"""
plot_results.py

從 results/processed/summary.csv 產生三張圖：
  - charts/throughput_by_env.png      各環境絕對 throughput 對照
  - charts/normalized_efficiency.png  公平化後的效率對照
  - charts/delay_impact.png           延遲對 goodput 的影響曲線

Usage:
    python3 plot_results.py --csv ../results/processed/summary.csv --out-dir ../charts
"""

import argparse
import csv
from pathlib import Path

import matplotlib.pyplot as plt


def load_rows(csv_path: Path) -> list[dict]:
    with open(csv_path) as f:
        return list(csv.DictReader(f))


def safe_float(val: str):
    try:
        return float(val)
    except (TypeError, ValueError):
        return None


def plot_throughput_by_env(rows: list[dict], out_path: Path):
    envs, values = [], []
    for r in rows:
        v = safe_float(r.get("hdtn_goodput_mbps"))
        if v is not None and r.get("delay_ms") == "0":
            envs.append(r["env"])
            values.append(v)

    if not envs:
        print("[plot_results] no baseline (delay=0) rows with goodput found; skipping throughput_by_env")
        return

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(envs, values, color="#4C72B0")
    ax.set_ylabel("HDTN Goodput (Mbps)")
    ax.set_title("HDTN Goodput by Environment (no delay)")
    plt.xticks(rotation=20, ha="right")
    fig.tight_layout()
    fig.savefig(out_path)
    print(f"[plot_results] wrote {out_path}")


def plot_normalized_efficiency(rows: list[dict], out_path: Path):
    envs, values = [], []
    for r in rows:
        v = safe_float(r.get("normalized_efficiency"))
        if v is not None and r.get("delay_ms") == "0":
            envs.append(r["env"])
            values.append(v)

    if not envs:
        print("[plot_results] no normalized_efficiency rows found; skipping normalized_efficiency chart")
        return

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(envs, values, color="#55A868")
    ax.set_ylabel("Normalized Efficiency (%)")
    ax.set_title("HDTN Goodput / iperf3 Baseline, by Environment")
    plt.xticks(rotation=20, ha="right")
    fig.tight_layout()
    fig.savefig(out_path)
    print(f"[plot_results] wrote {out_path}")


def plot_delay_impact(rows: list[dict], out_path: Path):
    by_env: dict[str, list[tuple[float, float]]] = {}
    for r in rows:
        delay = safe_float(r.get("delay_ms"))
        goodput = safe_float(r.get("hdtn_goodput_mbps"))
        if delay is not None and goodput is not None:
            by_env.setdefault(r["env"], []).append((delay, goodput))

    if not by_env:
        print("[plot_results] no delay-series rows found; skipping delay_impact chart")
        return

    fig, ax = plt.subplots(figsize=(8, 5))
    for env, points in by_env.items():
        points.sort()
        xs, ys = zip(*points)
        ax.plot(xs, ys, marker="o", label=env)

    ax.set_xlabel("Simulated Delay (ms)")
    ax.set_ylabel("HDTN Goodput (Mbps)")
    ax.set_title("Effect of Simulated Delay on HDTN Goodput")
    ax.legend()
    fig.tight_layout()
    fig.savefig(out_path)
    print(f"[plot_results] wrote {out_path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    rows = load_rows(args.csv)

    if not rows:
        print(f"[plot_results] {args.csv} has no rows yet. Run parse_results.py after collecting data.")
        return

    plot_throughput_by_env(rows, args.out_dir / "throughput_by_env.png")
    plot_normalized_efficiency(rows, args.out_dir / "normalized_efficiency.png")
    plot_delay_impact(rows, args.out_dir / "delay_impact.png")


if __name__ == "__main__":
    main()
