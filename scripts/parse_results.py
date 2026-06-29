#!/usr/bin/env python3
"""
parse_results.py

把 results/raw/<env>/ 底下的原始輸出（iperf json、HDTN log、
resource log）整理成 results/processed/summary.csv 的格式。

Usage:
    python3 parse_results.py --raw-dir ../results/raw --out ../results/processed/summary.csv
"""

import argparse
import csv
import json
import re
from pathlib import Path

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


def parse_iperf_json(path: Path):
    """從 iperf3 -J 輸出取得 Mbps。"""
    try:
        with open(path) as f:
            data = json.load(f)
        return data["end"]["sum_received"]["bits_per_second"] / 1e6
    except (FileNotFoundError, KeyError, json.JSONDecodeError):
        return None


def parse_hdtn_log(path: Path, duration_sec: float):
    """
    從 bpsink-async log 解析 goodput（Mbps）。

    2026-06-28 修正：原先取「最後一筆 Total Rate」會踩到 bpgen 收尾排水階段
    （duration 到了但仍有 unacked bundle 在收尾）的低速取樣，導致數字被嚴重
    低估（實測 B1-v2 最後一筆是 3023 Mbit/s，但測試期間穩定速率在 7000-7900
    Mbit/s 區間）。改成取「全部樣本的平均值」，更能代表整段測試的真實表現，
    且不受單一取樣點（尤其是收尾噪聲）影響。

    若需要排除暖機階段（第一筆通常明顯偏低，見 configs/bpsink/README.md），
    可考慮改成「排除第一筆與最後一筆後取平均」，但目前先用全部樣本平均，
    較簡單且保守。
    """
    if not path.exists():
        return None

    rate_pattern = re.compile(r"Total Rate:\s*([\d.]+)\s*Mbits/sec")
    all_rates = []
    last_total_bytes = None

    with open(path) as f:
        for line in f:
            rate_match = rate_pattern.search(line)
            if rate_match:
                all_rates.append(float(rate_match.group(1)))
                continue

            content = line.strip().rsplit(":", 1)[-1].strip()
            parts = content.split(",")
            if len(parts) == 4:
                try:
                    nums = [int(p.strip()) for p in parts]
                except ValueError:
                    continue
                last_total_bytes = nums[3]

    if all_rates:
        return sum(all_rates) / len(all_rates)

    if last_total_bytes is not None and duration_sec > 0:
        return (last_total_bytes * 8 / 1e6) / duration_sec

    return None


def parse_duplicate_count(path: Path):
    """從 bpsink-async log 取得 (rx_count, duplicate_count)。"""
    if not path.exists():
        return None

    last_rx_count = None
    last_dup_count = None
    with open(path) as f:
        for line in f:
            content = line.strip().rsplit(":", 1)[-1].strip()
            parts = content.split(",")
            if len(parts) == 4:
                try:
                    nums = [int(p.strip()) for p in parts]
                except ValueError:
                    continue
                last_rx_count, last_dup_count = nums[0], nums[1]

    if last_rx_count is None:
        return None
    return last_rx_count, last_dup_count


def parse_one_test_dir(test_dir: Path, env: str):
    """組裝單次測試的一筆 summary row。"""
    test_id = test_dir.name
    row = {field: "" for field in FIELDNAMES}
    row["env"] = env
    notes = [f"parsed_from={test_id}"]

    iperf_path = test_dir / f"{test_id}_iperf.json"
    iperf_mbps = parse_iperf_json(iperf_path)
    if iperf_mbps is not None:
        row["iperf_mbps"] = f"{iperf_mbps:.2f}"

    duration_sec = 60.0
    goodput = parse_hdtn_log(test_dir / f"{test_id}_bpsink.log", duration_sec)
    if goodput is not None:
        row["hdtn_goodput_mbps"] = f"{goodput:.2f}"
        row["duration_sec"] = f"{duration_sec:.0f}"

    if iperf_mbps and goodput:
        row["normalized_efficiency"] = f"{(goodput / iperf_mbps) * 100:.1f}"

    dup_info = parse_duplicate_count(test_dir / f"{test_id}_bpsink.log")
    if dup_info is not None:
        rx_count, dup_count = dup_info
        notes.append(f"rx_count={rx_count}")
        notes.append(f"duplicate_count={dup_count}")

    row["notes"] = ";".join(notes)
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
