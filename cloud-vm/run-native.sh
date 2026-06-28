#!/usr/bin/env bash
# run-native.sh
#
# 在 Cloud VM 上直接跑 HDTN process（不經 container），
# 對應 experiment-design.md 中的 Phase 0 C1 / C1-D。
#
# Usage:
#   ./run-native.sh --test-id C1 --payload-mb 1 --duration 60

set -euo pipefail

TEST_ID=""
PAYLOAD_MB=1
DURATION=60

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test-id) TEST_ID="$2"; shift 2 ;;
    --payload-mb) PAYLOAD_MB="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ -z "${TEST_ID}" ]; then
  echo "Usage: $0 --test-id <id> --payload-mb <n> --duration <sec>" >&2
  exit 1
fi

OUT_DIR="../results/raw/cloud-vm/${TEST_ID}"
mkdir -p "${OUT_DIR}"

echo "[run-native] test_id=${TEST_ID} payload=${PAYLOAD_MB}MB duration=${DURATION}s"
echo "[run-native] output -> ${OUT_DIR}"

# 1. 啟動 metrics 收集（背景）
../scripts/collect_metrics.sh start "${TEST_ID}" eth0 4558 "../pcaps/cloud-vm"

# 2. 跑 HDTN 測試（目前是骨架，需要補實際 binary 路徑，見 scripts/run_hdtn_test.sh）
../scripts/run_hdtn_test.sh "${TEST_ID}" "${PAYLOAD_MB}" "${DURATION}" "${OUT_DIR}"

# 3. 停止 metrics 收集
../scripts/collect_metrics.sh stop "${TEST_ID}"

echo "[run-native] done. Check ${OUT_DIR} and ../pcaps/cloud-vm/${TEST_ID}.pcap"
