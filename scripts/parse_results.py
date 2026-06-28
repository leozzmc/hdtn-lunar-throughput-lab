#!/usr/bin/env python3
"""
parse_results.py

把 results/raw/<env>/ 底下的原始輸出（iperf json、HDTN log、
resource log）整理成 results/processed/summary.csv 的格式。

這是骨架版本：欄位 schema 已定義，實際 parsing 邏輯需要依
run_hdtn_test.sh / collect_metrics.sh 實際輸出的 log 格式來補完。

Usage:
    python3 parse_results.py --raw-dir ../results/raw --out ../results/processed/summary.csv
"""

import argparse
import csv
import json
from pathlib import Path

# 與 docs/experiment-design.md 中定義的欄位保持一致
FIELDNAMES = [
    "date",
    "env",
    "host",
    "topology",
    "delay_ms",
    "loss_pct",
    "disruption",
    "payload_size_mb",
    "duration_sec",
    "iperf_mbps",
    "hdtn_goodput_mbps",
    "normalized_efficiency",
    "cpu_avg_pct",
    "mem_rss_mb",
    "notes",
]


def parse_iperf_json(path: Path) -> float | None:
    """從 iperf3 -J 輸出取得 Mbps。"""
    try:
        with open(path) as f:
            data = json.load(f)
        return data["end"]["sum_received"]["bits_per_second"] / 1e6
    except (FileNotFoundError, KeyError, json.JSONDecodeError):
        return None


def parse_hdtn_log(path: Path) -> float | None:
    """
    TODO: 從 bpsink log 解析實際 goodput。
    HDTN 的 bpsink-async 輸出格式需要實際跑過才能確認怎麼 parse，
    先放 placeholder，之後依實際 log 格式更新。
    """
    if not path.exists():
        return None
    # TODO: 實作實際的 log parsing
    return None


def parse_one_test_dir(test_dir: Path, env: str) -> dict:
    """組裝單次測試的一筆 summary row。"""
    test_id = test_dir.name
    row = {field: "" for field in FIELDNAMES}
    row["env"] = env
    row["notes"] = f"parsed_from={test_id}"

    iperf_path = test_dir / f"{test_id}_iperf.json"
    iperf_mbps = parse_iperf_json(iperf_path)
    if iperf_mbps is not None:
        row["iperf_mbps"] = f"{iperf_mbps:.2f}"

    goodput = parse_hdtn_log(test_dir / f"{test_id}_bpsink.log")
    if goodput is not None:
        row["hdtn_goodput_mbps"] = f"{goodput:.2f}"

    if iperf_mbps and goodput:
        row["normalized_efficiency"] = f"{(goodput / iperf_mbps) * 100:.1f}"

    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw-dir", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    rows = []
    for env_dir in sorted(args.raw_dir.iterdir()):
        if not env_dir.is_dir():
            continue
        env = env_dir.name
        for test_dir in sorted(env_dir.iterdir()):
            if test_dir.is_dir():
                rows.append(parse_one_test_dir(test_dir, env))

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(rows)

    print(f"[parse_results] wrote {len(rows)} rows -> {args.out}")
    if not rows:
        print("[parse_results] no rows found — check that results/raw/<env>/<test_id>/ "
              "directories exist with expected file naming.")


if __name__ == "__main__":
    main()
