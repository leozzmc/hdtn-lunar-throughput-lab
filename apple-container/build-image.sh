#!/usr/bin/env bash
# build-image.sh
#
# Build HDTN image for Apple `container` CLI.
# TODO: 確認 container CLI 是否能直接吃 ../docker/Dockerfile.hdtn，
# 或需要調整語法。

set -euo pipefail

echo "[build-image] building hdtn-lab image via Apple container CLI"
container build --tag hdtn-lab:latest -f ../docker/Dockerfile.hdtn ../

echo "[build-image] done. Verify with: container images list"
container images list
