#!/usr/bin/env bash
# setup_tc_delay.sh
#
# 在指定網路介面上套用 tc netem 延遲/遺失模擬。
# 用於模擬地月級 propagation delay（見 docs/limitations.md：
# 這只模擬 propagation delay 的尺度，不是完整鏈路模擬）。
#
# Usage:
#   ./setup_tc_delay.sh <interface> <delay_ms> [loss_pct]
#
# Example:
#   ./setup_tc_delay.sh eth0 1300        # 1300ms delay, no loss
#   ./setup_tc_delay.sh eth0 1300 1      # 1300ms delay, 1% loss

set -euo pipefail

IFACE="${1:?Usage: $0 <interface> <delay_ms> [loss_pct]}"
DELAY_MS="${2:?Usage: $0 <interface> <delay_ms> [loss_pct]}"
LOSS_PCT="${3:-0}"

echo "[setup_tc_delay] interface=${IFACE} delay=${DELAY_MS}ms loss=${LOSS_PCT}%"

# TODO: 依實際執行環境確認:
#   - 這個 interface 是否需要 sudo
#   - 是否已有既存的 qdisc（先用 clear_tc.sh 清掉再套用，避免疊加）
#   - container / VM 環境內 tc 工具是否需要額外安裝（iproute2 套件）

if [ "${LOSS_PCT}" != "0" ]; then
  sudo tc qdisc add dev "${IFACE}" root netem delay "${DELAY_MS}ms" loss "${LOSS_PCT}%"
else
  sudo tc qdisc add dev "${IFACE}" root netem delay "${DELAY_MS}ms"
fi

echo "[setup_tc_delay] applied. Verify with: tc qdisc show dev ${IFACE}"
tc qdisc show dev "${IFACE}"
