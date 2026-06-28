#!/usr/bin/env bash
# run_iperf_baseline.sh
#
# 取得該環境的 raw network throughput baseline，作為 normalized
# efficiency 的分母（見 docs/experiment-design.md）。
#
# Usage:
#   Server 端: ./run_iperf_baseline.sh server
#   Client 端: ./run_iperf_baseline.sh client <server_ip> <output_csv_path>

set -euo pipefail

MODE="${1:?Usage: $0 <server|client> [server_ip] [output_path]}"

case "${MODE}" in
  server)
    echo "[run_iperf_baseline] starting iperf3 server"
    iperf3 -s
    ;;
  client)
    SERVER_IP="${2:?client mode requires server_ip}"
    OUT_PATH="${3:-/tmp/iperf_baseline.json}"
    echo "[run_iperf_baseline] running client against ${SERVER_IP}, output -> ${OUT_PATH}"
    # TODO: 確認測試用的 protocol（TCP/UDP）與時長是否要跟 HDTN 測試一致
    # NASA 報告同時觀察 iperf3 與 end-to-end DTN throughput 的落差，
    # 這裡的 -t 60 與後續 HDTN 測試的 duration 應該保持一致
    iperf3 -c "${SERVER_IP}" -t 60 -J > "${OUT_PATH}"
    echo "[run_iperf_baseline] done. Mbps (parse with jq):"
    command -v jq >/dev/null 2>&1 && jq '.end.sum_received.bits_per_second / 1e6' "${OUT_PATH}" || echo "(install jq to auto-parse)"
    ;;
  *)
    echo "Unknown mode: ${MODE}" >&2
    exit 1
    ;;
esac
