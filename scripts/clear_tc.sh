#!/usr/bin/env bash
# clear_tc.sh
#
# 清除指定介面上的 tc qdisc 設定，回到 baseline 狀態。
# 每組測試結束、開始下一組前都應該先跑這個。
#
# Usage:
#   ./clear_tc.sh <interface>

set -euo pipefail

IFACE="${1:?Usage: $0 <interface>}"

echo "[clear_tc] clearing qdisc on ${IFACE}"
sudo tc qdisc del dev "${IFACE}" root 2>/dev/null || echo "[clear_tc] no qdisc to remove (already clean)"

tc qdisc show dev "${IFACE}"
