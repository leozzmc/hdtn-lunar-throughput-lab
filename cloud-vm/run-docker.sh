#!/usr/bin/env bash
# run-docker.sh
#
# 在 Cloud VM 上用 Docker 跑 container 化的 HDTN，
# 對應 experiment-design.md 中的 C2 / C3（Linux VM + Docker container）。
# 這組用來跟 Docker Desktop on macOS 做對照：同樣是 Docker，
# 但底下是「真正 Linux host 上的 Docker」而非「macOS 上跑 Linux VM 再跑 Docker」。

set -euo pipefail

TEST_ID="${1:?Usage: $0 <test_id> [delay_ms]}"
DELAY_MS="${2:-0}"

if ! command -v docker >/dev/null 2>&1; then
  echo "[run-docker] Docker not installed on this VM. Install with:"
  echo "  curl -fsSL https://get.docker.com | sudo sh"
  exit 1
fi

echo "[run-docker] test_id=${TEST_ID} delay=${DELAY_MS}ms"

# TODO: 沿用 ../docker/compose.single.yml 或 compose.multi.yml，
# 但 volume 路徑要改成這個 Cloud VM 上的路徑
echo "[run-docker] TODO: docker compose -f ../docker/compose.single.yml up"

echo "[run-docker] placeholder script complete."
