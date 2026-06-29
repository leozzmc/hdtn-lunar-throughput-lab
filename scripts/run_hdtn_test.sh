#!/usr/bin/env bash
# run_hdtn_test.sh
#
# 啟動 HDTN node，並用 bpgen / bpsink 跑一次 bundle 傳輸測試，收集 goodput。
#
# === 版本歷史 / 設計決策（排查記錄見 ../docs/limitations.md 第 9、10 節）===
#
# v2：B2（650ms delay）案例顯示 bpgen-async 原本前景執行、沒有 timeout
#     保護，在高延遲下 STCP outduct 排空（drain）時間可能遠超預期
#     （實測超過 5 分鐘）。改為：
#       1. bpgen-async 用 GNU `timeout --kill-after` 執行，bounded wall-clock
#       2. 輸出 timeline.tsv，記錄每個關鍵階段的 timestamp
#       3. trap cleanup（EXIT/INT/TERM 分開處理），避免留下背景 process
#       4. 輸出 metadata.json，記錄這次測試的實際參數與結束狀態
#
# v3：smoke test 排查發現 `--bundle-rate=0`（as fast as possible）會讓
#     bpgen 立刻填滿整個 pipeline window，不論 duration 多短，導致即使
#     極短測試也會卡進長時間 destructor drain。新增 BUNDLE_RATE。
#
# v4：即使 window=5、bundle-rate=1，1MiB payload 仍需 60 秒以上 grace
#     才能讓 bpgen destructor 乾淨排空（已用 SMOKE-rate1-grace60 驗證：
#     bundle_count=6, totalBundlesSent/Acked=6, bpsink Rx Count=6 全部
#     對上，exited_normally，但 wall_clock_total_sec=71.9，對 smoke test
#     而言太長）。新增 PAYLOAD_BYTES，可覆寫 payload 大小，讓 harness
#     smoke test 用遠小於 1MiB 的 payload（例如 65536，64KiB）在合理
#     時間內驗證 process lifecycle。
#
# 已知限制（留給之後改進，這版刻意不做）：
#   - bpsink log 沒有逐行 timestamp，timeline.tsv 只能提供粗略事件邊界，
#     無法精確切分某一筆 bpsink rate 樣本屬於 generation 還是 drain phase
#   - 沒有背景持續取樣 tc qdisc 狀態（只能事後查一次）
#   - DRAIN_SEC 的合理預設值依 payload/window/rate 而不同，沒有統一公式，
#     需要依實際情境調整（見 limitations.md 第 10 節的對照表）
#
# Usage:
#   ./run_hdtn_test.sh <test_id> <payload_size_mb> <duration_sec> <output_dir>
#
# 環境變數覆寫：
#   HDTN_SOURCE_ROOT   (default: ${HOME}/hdtn-lab/HDTN)
#   BPGEN_GRACE_SEC    (default: 120)  bpgen duration 結束後，最多再給多少秒排空
#   DRAIN_SEC          (default: 10)   bpgen 正常退出後，再等多久才 kill bpsink/hdtn
#   KILL_GRACE_SEC     (default: 10)   bpgen timeout 後，TERM 與 KILL 之間的等待
#   BUNDLE_RATE        (default: 0)    bpgen --bundle-rate 參數。
#                                      0 = as fast as possible，會立刻塞滿
#                                      pipeline window。smoke test 建議用
#                                      明確低速率（例如 1）。
#   PAYLOAD_BYTES      (default: 空，使用 PAYLOAD_MB * 1024 * 1024)
#                                      覆寫 bundle 大小（單位 bytes）。
#                                      harness smoke test 建議用遠小於
#                                      1MiB 的值，例如 65536（64KiB），
#                                      避免被 STCP drain 行為拖長測試時間。

set -euo pipefail

TEST_ID="${1:?Usage: $0 <test_id> <payload_size_mb> <duration_sec> <output_dir>}"
PAYLOAD_MB="${2:?missing payload_size_mb}"
DURATION="${3:?missing duration_sec}"
OUT_DIR="${4:?missing output_dir}"

mkdir -p "${OUT_DIR}"

HDTN_SOURCE_ROOT="${HDTN_SOURCE_ROOT:-${HOME}/hdtn-lab/HDTN}"
BPGEN_GRACE_SEC="${BPGEN_GRACE_SEC:-120}"
DRAIN_SEC="${DRAIN_SEC:-10}"
KILL_GRACE_SEC="${KILL_GRACE_SEC:-10}"
BUNDLE_RATE="${BUNDLE_RATE:-0}"
PAYLOAD_BYTES="${PAYLOAD_BYTES:-}"
BPGEN_WALL_TIMEOUT_SEC=$((DURATION + BPGEN_GRACE_SEC))

HDTN_BIN="${HDTN_SOURCE_ROOT}/build/module/hdtn_one_process/hdtn-one-process"
BPGEN_BIN="${HDTN_SOURCE_ROOT}/build/common/bpcodec/apps/bpgen-async"
BPSINK_BIN="${HDTN_SOURCE_ROOT}/build/common/bpcodec/apps/bpsink-async"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HDTN_CONFIG="${HDTN_CONFIG:-${SCRIPT_DIR}/../configs/hdtn/hdtn.json}"
CONTACT_PLAN="${CONTACT_PLAN:-${SCRIPT_DIR}/../configs/hdtn/contact-plan.json}"
BPGEN_OUTDUCT="${BPGEN_OUTDUCT:-${SCRIPT_DIR}/../configs/bpgen/outduct-stcp-port4556.json}"
BPSINK_INDUCT="${BPSINK_INDUCT:-${SCRIPT_DIR}/../configs/bpsink/induct-stcp-port4558.json}"

for bin in "${HDTN_BIN}" "${BPGEN_BIN}" "${BPSINK_BIN}"; do
  if [ ! -x "${bin}" ]; then
    echo "[run_hdtn_test] ERROR: binary not found or not executable: ${bin}" >&2
    echo "  Check HDTN_SOURCE_ROOT (currently: ${HDTN_SOURCE_ROOT})" >&2
    exit 1
  fi
done

if ! command -v timeout >/dev/null 2>&1; then
  echo "[run_hdtn_test] ERROR: GNU 'timeout' command not found. Install coreutils." >&2
  exit 1
fi

# 決定實際 bundle size：PAYLOAD_BYTES 若有設定就覆寫 PAYLOAD_MB 算出來的值。
if [ -n "${PAYLOAD_BYTES}" ]; then
  if ! [[ "${PAYLOAD_BYTES}" =~ ^[0-9]+$ ]]; then
    echo "[run_hdtn_test] ERROR: PAYLOAD_BYTES must be a positive integer, got: ${PAYLOAD_BYTES}" >&2
    exit 1
  fi
  BUNDLE_SIZE_BYTES="${PAYLOAD_BYTES}"
else
  BUNDLE_SIZE_BYTES=$((PAYLOAD_MB * 1024 * 1024))
fi

echo "[run_hdtn_test] test_id=${TEST_ID} payload_arg=${PAYLOAD_MB}MB actual_bundle_size_bytes=${BUNDLE_SIZE_BYTES} duration=${DURATION}s bundle_rate=${BUNDLE_RATE}"
echo "[run_hdtn_test] bpgen wall-clock timeout = ${BPGEN_WALL_TIMEOUT_SEC}s (duration + BPGEN_GRACE_SEC=${BPGEN_GRACE_SEC}s)"

HDTN_LOG="${OUT_DIR}/${TEST_ID}_hdtn.log"
BPSINK_LOG="${OUT_DIR}/${TEST_ID}_bpsink.log"
BPGEN_LOG="${OUT_DIR}/${TEST_ID}_bpgen.log"
TIMELINE="${OUT_DIR}/${TEST_ID}_timeline.tsv"
METADATA="${OUT_DIR}/${TEST_ID}_metadata.json"

PID_DIR="/tmp/hdtn-lab-pids"
mkdir -p "${PID_DIR}"

HDTN_PID=""
BPSINK_PID=""
CLEANED_UP=0

# cleanup：避免任何退出路徑（正常結束、Ctrl-C、錯誤）留下背景的
# hdtn-one-process / bpsink-async 變成孤兒程序。bpgen-async 不需要在這裡
# 處理，因為它是用 `timeout` 跑在前景，timeout 指令本身會負責管理它的
# 生命週期（包含 TERM/KILL），不會是孤兒。
cleanup() {
  if [ "${CLEANED_UP}" -eq 1 ]; then
    return
  fi
  CLEANED_UP=1
  echo "[run_hdtn_test] cleanup: ensuring no background processes are left running..."
  [ -n "${BPSINK_PID}" ] && kill "${BPSINK_PID}" 2>/dev/null || true
  [ -n "${HDTN_PID}" ] && kill "${HDTN_PID}" 2>/dev/null || true
  rm -f "${PID_DIR}/${TEST_ID}.bpsink.pid" "${PID_DIR}/${TEST_ID}.hdtn.pid"
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# timeline 記錄：epoch 秒 (含小數) + tab + 事件名稱
echo -e "epoch_seconds\tevent" > "${TIMELINE}"
log_timeline() {
  echo -e "$(date +%s.%N)\t$1" >> "${TIMELINE}"
}

log_timeline "test_start"

echo "[run_hdtn_test] starting hdtn-one-process..."
log_timeline "hdtn_start"
"${HDTN_BIN}" \
  --hdtn-config-file="${HDTN_CONFIG}" \
  --contact-plan-file="${CONTACT_PLAN}" \
  > "${HDTN_LOG}" 2>&1 &
HDTN_PID=$!
echo "${HDTN_PID}" > "${PID_DIR}/${TEST_ID}.hdtn.pid"
echo "[run_hdtn_test] hdtn-one-process pid=${HDTN_PID}, log=${HDTN_LOG}"

echo "[run_hdtn_test] waiting 5s for hdtn-one-process induct/outduct to come up..."
sleep 5

echo "[run_hdtn_test] starting bpsink-async..."
log_timeline "bpsink_start"
"${BPSINK_BIN}" \
  --my-uri-eid=ipn:2.1 \
  --inducts-config-file="${BPSINK_INDUCT}" \
  > "${BPSINK_LOG}" 2>&1 &
BPSINK_PID=$!
echo "${BPSINK_PID}" > "${PID_DIR}/${TEST_ID}.bpsink.pid"
echo "[run_hdtn_test] bpsink-async pid=${BPSINK_PID}, log=${BPSINK_LOG}"

echo "[run_hdtn_test] waiting 2s for bpsink induct to bind..."
sleep 2

echo "[run_hdtn_test] starting bpgen-async (bounded foreground, generation duration=${DURATION}s, bundle_rate=${BUNDLE_RATE}, bundle_size_bytes=${BUNDLE_SIZE_BYTES}, wall timeout=${BPGEN_WALL_TIMEOUT_SEC}s)..."
log_timeline "bpgen_start"

set +e
timeout --kill-after="${KILL_GRACE_SEC}s" "${BPGEN_WALL_TIMEOUT_SEC}s" \
  "${BPGEN_BIN}" \
    --bundle-size="${BUNDLE_SIZE_BYTES}" \
    --bundle-rate="${BUNDLE_RATE}" \
    --duration="${DURATION}" \
    --my-uri-eid=ipn:1.1 \
    --dest-uri-eid=ipn:2.1 \
    --outducts-config-file="${BPGEN_OUTDUCT}" \
    > "${BPGEN_LOG}" 2>&1
BPGEN_RC=$?
set -e

# timeout 的 exit code 慣例：124 = 在 timeout 時間到時被 TERM；
# 137 = 128+9，代表 kill-after 寬限期過後被 SIGKILL 強制終止。
if [ "${BPGEN_RC}" -eq 0 ]; then
  BPGEN_EXIT_STATUS="exited_normally"
  log_timeline "bpgen_exited_normally"
elif [ "${BPGEN_RC}" -eq 124 ] || [ "${BPGEN_RC}" -eq 137 ]; then
  BPGEN_EXIT_STATUS="timeout_killed"
  log_timeline "bpgen_timeout_killed"
  echo "[run_hdtn_test] WARNING: bpgen-async exceeded wall-clock timeout (${BPGEN_WALL_TIMEOUT_SEC}s) and was killed." >&2
  echo "  This likely means STCP outduct drain is taking longer than expected" >&2
  echo "  under the current delay/loss/bundle-rate/payload settings (see docs/limitations.md #9, #10)." >&2
else
  BPGEN_EXIT_STATUS="exited_with_error_${BPGEN_RC}"
  log_timeline "bpgen_exited_with_error_${BPGEN_RC}"
  echo "[run_hdtn_test] WARNING: bpgen-async exited with unexpected code ${BPGEN_RC}." >&2
fi

echo "[run_hdtn_test] bpgen phase complete. exit_status=${BPGEN_EXIT_STATUS}, rc=${BPGEN_RC}"

echo "[run_hdtn_test] waiting ${DRAIN_SEC}s for any remaining in-flight bundles to settle..."
log_timeline "drain_start"
sleep "${DRAIN_SEC}"
log_timeline "drain_end"

echo "[run_hdtn_test] stopping bpsink-async (pid=${BPSINK_PID})..."
log_timeline "bpsink_stop"
kill "${BPSINK_PID}" 2>/dev/null || true
wait "${BPSINK_PID}" 2>/dev/null || true
rm -f "${PID_DIR}/${TEST_ID}.bpsink.pid"
BPSINK_PID=""

echo "[run_hdtn_test] stopping hdtn-one-process (pid=${HDTN_PID})..."
log_timeline "hdtn_stop"
kill "${HDTN_PID}" 2>/dev/null || true
wait "${HDTN_PID}" 2>/dev/null || true
rm -f "${PID_DIR}/${TEST_ID}.hdtn.pid"
HDTN_PID=""

log_timeline "test_end"

# 算出真實 wall-clock 總長（從 timeline.tsv 的第一筆和最後一筆事件）
TEST_START_EPOCH=$(awk -F'\t' 'NR==2{print $1}' "${TIMELINE}")
TEST_END_EPOCH=$(awk -F'\t' 'END{print $1}' "${TIMELINE}")
WALL_CLOCK_TOTAL_SEC=$(awk -v a="${TEST_START_EPOCH}" -v b="${TEST_END_EPOCH}" 'BEGIN{printf "%.1f", b-a}')

cat > "${METADATA}" << EOF
{
  "test_id": "${TEST_ID}",
  "payload_size_mb": ${PAYLOAD_MB},
  "bundle_size_bytes": ${BUNDLE_SIZE_BYTES},
  "payload_bytes_override": "${PAYLOAD_BYTES}",
  "bundle_rate": ${BUNDLE_RATE},
  "configured_duration_sec": ${DURATION},
  "bpgen_grace_sec": ${BPGEN_GRACE_SEC},
  "bpgen_wall_timeout_sec": ${BPGEN_WALL_TIMEOUT_SEC},
  "bpgen_exit_status": "${BPGEN_EXIT_STATUS}",
  "bpgen_return_code": ${BPGEN_RC},
  "drain_sec": ${DRAIN_SEC},
  "wall_clock_total_sec": ${WALL_CLOCK_TOTAL_SEC}
}
EOF

echo "[run_hdtn_test] done. Outputs:"
echo "  ${HDTN_LOG}"
echo "  ${BPGEN_LOG}"
echo "  ${BPSINK_LOG}"
echo "  ${TIMELINE}"
echo "  ${METADATA}"
if [ "${BPGEN_EXIT_STATUS}" = "timeout_killed" ]; then
  echo "[run_hdtn_test] *** WARNING: bpgen was force-killed after timeout. ***"
  echo "  This test result's goodput numbers should be treated as a LOWER BOUND,"
  echo "  not a clean measurement. See metadata.json for details."
fi
echo "[run_hdtn_test] check ${BPSINK_LOG} for the 'Rx Count, Duplicate Count, Total Count, Total bytes Rx' line."
echo "  See ${TIMELINE} for rough phase boundaries (bpsink log lines are NOT"
echo "  individually timestamped, so generation-phase vs drain-phase samples"
echo "  cannot be precisely split yet)."
