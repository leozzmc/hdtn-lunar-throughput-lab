#!/usr/bin/env python3
"""
parse_results.py

把 results/raw/<env>/ 底下的原始輸出（iperf json、HDTN log、bpsink log、
metadata.json）整理成 results/processed/summary.csv 的格式。

2026-06-28 修正（B2-r2 案例後）：原本單一的 `hdtn_goodput_mbps` 欄位
語義不清，容易把三種不同的速率混為一談：

  1. bpsink positive interval rate 的平均值（取自 "Total Rate" log，
     只在「有 byte/bundle 變化」時才印出，idle window 會被跳過不印）
  2. delivered goodput / 設定的 generation duration（"generation-window
     goodput"）
  3. delivered goodput / 真實 wall-clock 總時長（"wall-clock goodput"，
     需要從 metadata.json 讀取 run_hdtn_test.sh 算出的真實總時長）

詳見 docs/limitations.md 第 9 節「B2-r2 復現實驗」的說明：B2-r2 這組
25 筆 positive interval 樣本全部是 1.6777 Mbit/s，但這不代表整場測試
每 5 秒都送達 1 個 bundle——wall-clock 264.6 秒裡有大量沒有送達任何
bundle 的靜默窗口被跳過、不留記錄。三個指標衡量的是不同的事，
拆成獨立欄位輸出，不能用同一個含糊欄位代表。

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
    "bundle_size_bytes",
    "bundle_rate",
    "payload_bytes_override",
    "duration_sec",
    "wall_clock_total_sec",
    "bpgen_exit_status",
    "iperf_mbps",
    "hdtn_interval_rate_avg_mbps",
    "hdtn_delivered_goodput_mbps",
    "hdtn_wall_goodput_mbps",
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


def parse_metadata(path: Path):
    """
    讀取 run_hdtn_test.sh v4 輸出的 metadata.json（若存在）。
    舊版測試（例如 C1、B1，跑骨架版 run_hdtn_test.sh 時）沒有這個檔案，
    回傳 None，呼叫端要對應處理成欄位留空，不要假設一定存在。
    """
    if not path.exists():
        return None
    try:
        with open(path) as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return None


def parse_bpsink_log(path: Path):
    """
    從 bpsink-async log 解析三類數據：

    1. positive interval rate 樣本列表（"Total Rate" 那行，可能不是
       每個 5 秒窗口都有，只在有變化時才印，見本檔開頭說明）
    2. 結束時的累積統計行："Rx Count, Duplicate Count, Total Count,
       Total bytes Rx" 後面那行 "<int>,<int>,<int>,<int>"
    3. rx_count / duplicate_count（供 notes 欄位記錄）

    回傳 dict：
      {
        "interval_rates": [float, ...],  # 全部 positive interval 樣本
        "total_bytes_rx": int or None,   # 最終累積送達 bytes
        "rx_count": int or None,
        "duplicate_count": int or None,
      }
    """
    result = {
        "interval_rates": [],
        "total_bytes_rx": None,
        "rx_count": None,
        "duplicate_count": None,
    }

    if not path.exists():
        return result

    rate_pattern = re.compile(r"Payload Only Rate:\s*([\d.]+)\s*Mbits/sec")

    with open(path) as f:
        for line in f:
            rate_match = rate_pattern.search(line)
            if rate_match:
                result["interval_rates"].append(float(rate_match.group(1)))
                continue

            # 累積統計行：先取最後一個冒號之後的內容，再切逗號，
            # 避免 log 前綴（例如 "[ bpsink ][ info ]:"）裡的方括號干擾。
            content = line.strip().rsplit(":", 1)[-1].strip()
            parts = content.split(",")
            if len(parts) == 4:
                try:
                    nums = [int(p.strip()) for p in parts]
                except ValueError:
                    continue
                result["rx_count"] = nums[0]
                result["duplicate_count"] = nums[1]
                result["total_bytes_rx"] = nums[3]

    return result


def parse_one_test_dir(test_dir: Path, env: str) -> dict:
    """組裝單次測試的一筆 summary row。"""
    test_id = test_dir.name
    row = {field: "" for field in FIELDNAMES}
    row["env"] = env
    notes = [f"parsed_from={test_id}"]

    iperf_path = test_dir / f"{test_id}_iperf.json"
    iperf_mbps = parse_iperf_json(iperf_path)
    if iperf_mbps is not None:
        row["iperf_mbps"] = f"{iperf_mbps:.2f}"

    metadata = parse_metadata(test_dir / f"{test_id}_metadata.json")

    # duration_sec：優先用 metadata 裡的 configured_duration_sec
    # （v4 harness 才有），舊版測試沒有 metadata.json 時留空，
    # 不要再像舊版一樣 hardcode 60 —— 那是造成 B1/B1-v2 goodput
    # 算錯的根因之一，現在改成「沒有確切資訊就不要編造數字」。
    duration_sec = None
    if metadata is not None:
        duration_sec = metadata.get("configured_duration_sec")
        row["payload_size_mb"] = str(metadata.get("payload_size_mb", ""))
        row["duration_sec"] = str(duration_sec) if duration_sec is not None else ""
        row["bundle_size_bytes"] = str(metadata.get("bundle_size_bytes", ""))
        row["bundle_rate"] = str(metadata.get("bundle_rate", ""))
        row["payload_bytes_override"] = metadata.get("payload_bytes_override", "")
        row["wall_clock_total_sec"] = str(metadata.get("wall_clock_total_sec", ""))
        row["bpgen_exit_status"] = metadata.get("bpgen_exit_status", "")
        if metadata.get("bpgen_exit_status") == "timeout_killed":
            notes.append("INCOMPLETE_LOWER_BOUND(bpgen_timeout_killed)")

    bpsink_data = parse_bpsink_log(test_dir / f"{test_id}_bpsink.log")

    # 指標 1：positive interval rate 的平均值
    if bpsink_data["interval_rates"]:
        avg_interval_rate = sum(bpsink_data["interval_rates"]) / len(bpsink_data["interval_rates"])
        row["hdtn_interval_rate_avg_mbps"] = f"{avg_interval_rate:.4f}"
        notes.append(f"n_interval_samples={len(bpsink_data['interval_rates'])}")

    total_bytes_rx = bpsink_data["total_bytes_rx"]

    # 指標 2：generation-window goodput（送達 bytes / 設定的 generation duration）
    # 只有在 duration_sec 確實存在（來自 metadata.json）時才能算，
    # 否則寧可留空，不要用猜測的數字。
    if total_bytes_rx is not None and duration_sec:
        try:
            duration_sec_f = float(duration_sec)
            if duration_sec_f > 0:
                delivered_goodput = (total_bytes_rx * 8 / 1e6) / duration_sec_f
                row["hdtn_delivered_goodput_mbps"] = f"{delivered_goodput:.4f}"
        except (TypeError, ValueError):
            pass

    # 指標 3：wall-clock goodput（送達 bytes / 真實總耗時，來自 metadata.json）
    if metadata is not None and total_bytes_rx is not None:
        wall_clock_total_sec = metadata.get("wall_clock_total_sec")
        if wall_clock_total_sec:
            try:
                wall_clock_f = float(wall_clock_total_sec)
                if wall_clock_f > 0:
                    wall_goodput = (total_bytes_rx * 8 / 1e6) / wall_clock_f
                    row["hdtn_wall_goodput_mbps"] = f"{wall_goodput:.4f}"
            except (TypeError, ValueError):
                pass

    # normalized_efficiency：用 delivered goodput（generation-window）當分子，
    # 這跟 iperf baseline 比較的尺度比較一致（都是「設定的測試窗口內的速率」），
    # 而不是 wall-clock goodput（那個分母包含了排空/drain 時間，跟 iperf
    # baseline 量測的東西不是同一種尺度，放在一起比會誤導）。
    if iperf_mbps and row["hdtn_delivered_goodput_mbps"]:
        try:
            delivered = float(row["hdtn_delivered_goodput_mbps"])
            row["normalized_efficiency"] = f"{(delivered / iperf_mbps) * 100:.1f}"
        except ValueError:
            pass

    if bpsink_data["rx_count"] is not None:
        notes.append(f"rx_count={bpsink_data['rx_count']}")
    if bpsink_data["duplicate_count"] is not None:
        notes.append(f"duplicate_count={bpsink_data['duplicate_count']}")

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
