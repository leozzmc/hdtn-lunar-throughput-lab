#!/usr/bin/env bash
# run_hdtn_test.sh
#
# 啟動 HDTN node，並用 bpgen / bpsink 跑一次 bundle 傳輸測試，
# 收集 goodput。這是骨架版本 —— HDTN binary 路徑、config 路徑、
# bpgen/bpsink 參數都需要依實際 build 結果填入。
#
# 參考 NASA HDTN README 的 runscripts 目錄（每個 release 可能不同，
# 動手時請對照當下 clone 的 commit 內容，不要直接照抄這裡的路徑）。
#
# Usage:
#   ./run_hdtn_test.sh <test_id> <payload_size_mb> <duration_sec> <output_dir>

set -euo pipefail

TEST_ID="${1:?Usage: $0 <test_id> <payload_size_mb> <duration_sec> <output_dir>}"
PAYLOAD_MB="${2:?missing payload_size_mb}"
DURATION="${3:?missing duration_sec}"
OUT_DIR="${4:?missing output_dir}"

mkdir -p "${OUT_DIR}"

echo "[run_hdtn_test] test_id=${TEST_ID} payload=${PAYLOAD_MB}MB duration=${DURATION}s"

# TODO: 填入實際路徑（依 HDTN build 輸出位置調整）
HDTN_BIN="${HDTN_BIN:-/path/to/HDTN/build/module/hdtn_one_process/hdtn-one-process}"
HDTN_CONFIG="${HDTN_CONFIG:-../configs/hdtn/hdtn.json}"
CONTACT_PLAN="${CONTACT_PLAN:-../configs/hdtn/contact-plan.json}"
BPGEN_BIN="${BPGEN_BIN:-/path/to/HDTN/build/common/bpcodec/apps/bpgen-async}"
BPSINK_BIN="${BPSINK_BIN:-/path/to/HDTN/build/common/bpcodec/apps/bpsink-async}"

echo "[run_hdtn_test] TODO: 以下指令為示意，需依實際 binary 與參數調整"
echo "  ${HDTN_BIN} --contact-plan-file=${CONTACT_PLAN} --hdtn-config-file=${HDTN_CONFIG}"
echo "  ${BPSINK_BIN} ... > ${OUT_DIR}/${TEST_ID}_bpsink.log &"
echo "  ${BPGEN_BIN} --bundle-size-bytes=$((PAYLOAD_MB * 1024 * 1024)) --duration=${DURATION} ... > ${OUT_DIR}/${TEST_ID}_bpgen.log"

# TODO: 实际启动顺序通常是 hdtn -> bpsink -> bpgen，并需要等待
# linkUp / induct 就绪的事件后才送 bundle，否则第一批 bundle 可能丢失。
# 启动后台 process 时记得保存 PID 以便测试结束后 kill。

echo "[run_hdtn_test] placeholder run complete. Fill in real binary calls before use."
