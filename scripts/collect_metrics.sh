#!/usr/bin/env bash
# collect_metrics.sh
#
# 在測試執行期間於背景收集 CPU / memory，並啟動 tcpdump 抓包。
# 建議在 run_hdtn_test.sh 之前先啟動這個腳本（背景執行），
# 測試結束後再停止。
#
# Usage:
#   ./collect_metrics.sh start <test_id> <pcap_iface> <pcap_port> <output_dir>
#   ./collect_metrics.sh stop <test_id>

set -euo pipefail

ACTION="${1:?Usage: $0 <start|stop> <test_id> [pcap_iface] [pcap_port] [output_dir]}"
TEST_ID="${2:?missing test_id}"

PID_DIR="/tmp/hdtn-lab-pids"
mkdir -p "${PID_DIR}"

case "${ACTION}" in
  start)
    IFACE="${3:?missing pcap_iface}"
    PORT="${4:-4558}"
    OUT_DIR="${5:?missing output_dir}"
    mkdir -p "${OUT_DIR}"

    echo "[collect_metrics] starting tcpdump on ${IFACE} port ${PORT}"
    sudo tcpdump -i "${IFACE}" -vv -s0 "port ${PORT}" -w "${OUT_DIR}/${TEST_ID}.pcap" &
    echo $! > "${PID_DIR}/${TEST_ID}.tcpdump.pid"

    # TODO: 依環境選擇合適的資源監控方式
    #   Linux: top -b -d 1 / vmstat 1 / pidstat 1
    #   macOS: top -l 0 -s 1
    echo "[collect_metrics] TODO: 啟動 CPU/memory 監控迴圈，寫入 ${OUT_DIR}/${TEST_ID}_resources.log"
    ;;
  stop)
    if [ -f "${PID_DIR}/${TEST_ID}.tcpdump.pid" ]; then
      TCPDUMP_PID=$(cat "${PID_DIR}/${TEST_ID}.tcpdump.pid")
      echo "[collect_metrics] stopping tcpdump pid=${TCPDUMP_PID}"
      sudo kill "${TCPDUMP_PID}" 2>/dev/null || true
      rm -f "${PID_DIR}/${TEST_ID}.tcpdump.pid"
    else
      echo "[collect_metrics] no tcpdump pid file found for ${TEST_ID}"
    fi
    # TODO: 停止資源監控迴圈
    ;;
  *)
    echo "Unknown action: ${ACTION}" >&2
    exit 1
    ;;
esac
