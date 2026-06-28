#!/usr/bin/env bash
# run-single.sh
#
# Topology: single — bpgen/hdtn/bpsink 全部在同一個 Apple container
# lightweight VM 內。

set -euo pipefail

echo "[run-single] starting single hdtn-lab container"

# TODO: 確認 container CLI 的 run 參數語法（volume mount、network 等）
container run -it \
  --name hdtn-single \
  hdtn-lab:latest \
  /bin/bash

echo "[run-single] container exited. Results expected under ../results/raw/apple-container/"
