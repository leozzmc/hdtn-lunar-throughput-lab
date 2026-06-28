#!/usr/bin/env bash
# setup-ubuntu.sh
#
# 在 Cloud Linux VM（Ubuntu）上安裝依賴並 build HDTN。
# TODO: 鎖定的 commit 與 ../docs/environment-matrix.md 保持一致。

set -euo pipefail

echo "[setup-ubuntu] installing dependencies"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    libboost-all-dev \
    libzmq3-dev \
    libssl-dev \
    iproute2 \
    iputils-ping \
    tcpdump \
    iperf3 \
    jq

WORKDIR="${HOME}/hdtn-lab"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

if [ ! -d HDTN ]; then
  echo "[setup-ubuntu] cloning nasa/HDTN"
  git clone https://github.com/nasa/HDTN.git
fi

cd HDTN
# TODO: checkout 鎖定的 commit
# git checkout <locked_commit>

echo "[setup-ubuntu] TODO: 對照 HDTN README 的 Linux build 章節，
確認 CMake flags（例如是否需要關閉某些 hardware acceleration 選項），
再執行："
echo "  mkdir -p build && cd build && cmake .. && make -j\$(nproc)"

echo "[setup-ubuntu] dependency install complete. Build step left as TODO."
