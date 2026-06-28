#!/usr/bin/env bash
# run-multi.sh
#
# Topology: multi — bpgen、hdtn、bpsink 各自一個獨立的 Apple container
# lightweight VM。這是測試「per-container microVM 模型」下跨 VM
# 網路路徑對 throughput 影響的關鍵組。
#
# TODO（見 ../docs/limitations.md 與 README 的「關鍵待確認事項」）：
#   - 三個 container 之間如何發現彼此（IP-based？DNS？）
#   - tc netem 是否能在這個環境下使用

set -euo pipefail

echo "[run-multi] starting hdtn-node container"
container run -d --name hdtn-node hdtn-lab:latest /bin/bash -c "sleep infinity"

echo "[run-multi] starting bpsink container"
container run -d --name bpsink hdtn-lab:latest /bin/bash -c "sleep infinity"

echo "[run-multi] starting bpgen container"
container run -d --name bpgen hdtn-lab:latest /bin/bash -c "sleep infinity"

echo "[run-multi] TODO: 確認各 container 的 IP（container CLI 應該會自動配發），"
echo "  填入各自的 HDTN config / contact plan，再用 container exec 啟動 process"
echo ""
echo "  container exec hdtn-node <hdtn_command>"
echo "  container exec bpsink <bpsink_command>"
echo "  container exec bpgen <bpgen_command>"

echo "[run-multi] placeholder script complete."
