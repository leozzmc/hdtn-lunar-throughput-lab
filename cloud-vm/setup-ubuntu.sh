#!/usr/bin/env bash
# setup-ubuntu.sh
#
# 在 Cloud Linux VM（Ubuntu 24.04 LTS / EC2 t3.medium 或以上）上
# 安裝依賴並 build HDTN。
#
# 對應規格（見 ../docs/environment-matrix.md）：
#   region: us-east-1 / instance: t3.medium 以上 / storage: 20GB+
#
# TODO: 鎖定的 commit 與 ../docs/environment-matrix.md 保持一致。

set -euo pipefail

echo "[setup-ubuntu] ==== Pre-flight checks ===="

# 檢查可用記憶體（HDTN + Boost 編譯吃記憶體，t3.micro 1GB 會 OOM）
MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_MB=$((MEM_KB / 1024))
echo "[setup-ubuntu] detected memory: ${MEM_MB}MB"
if [ "${MEM_MB}" -lt 3500 ]; then
  echo "[setup-ubuntu] WARNING: less than ~4GB RAM detected."
  echo "  Boost + HDTN compilation is likely to OOM or be extremely slow on"
  echo "  t3.micro (1GB) / t3.small (2GB). Recommended: t3.medium (4GB) or larger."
  read -p "[setup-ubuntu] Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "[setup-ubuntu] aborting. Resize the instance and re-run."
    exit 1
  fi
fi

# 檢查可用磁碟空間（boost-all-dev + build 產物 + log/pcap 容易吃滿 8GB）
AVAIL_KB=$(df --output=avail / | tail -1 | tr -d ' ')
AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
echo "[setup-ubuntu] detected available disk space on /: ${AVAIL_GB}GB"
if [ "${AVAIL_GB}" -lt 15 ]; then
  echo "[setup-uburu] WARNING: less than ~15GB free disk space detected."
  echo "  boost-all-dev + HDTN build artifacts can easily exceed 8GB total."
  echo "  Recommended: 20GB+ EBS volume."
  read -p "[setup-ubuntu] Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "[setup-ubuntu] aborting. Resize the EBS volume and re-run."
    exit 1
  fi
fi

echo "[setup-ubuntu] ==== Installing dependencies ===="

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

echo "[setup-ubuntu] checking dependency versions against HDTN minimums"
echo "  (HDTN requires: CMake >=3.12, Boost >=1.66.0 (<=1.86), gcc >=9.3.0)"
cmake --version | head -1
gcc --version | head -1
dpkg -s libboost-dev 2>/dev/null | grep -i version || echo "  (libboost-dev version check skipped)"

WORKDIR="${HOME}/hdtn-lab"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

echo "[setup-ubuntu] ==== Cloning nasa/HDTN ===="

if [ ! -d HDTN ]; then
  git clone https://github.com/nasa/HDTN.git
fi

cd HDTN

# TODO: checkout 鎖定的 commit，並把 hash 記錄進
#       ../../docs/environment-matrix.md 的「鎖定 commit」欄位
# git checkout <locked_commit>
echo "[setup-ubuntu] current HEAD: $(git rev-parse HEAD)"
echo "[setup-ubuntu] >>> TODO: lock this commit hash in docs/environment-matrix.md <<<"

echo "[setup-ubuntu] ==== Build step (not yet automated) ===="
echo "[setup-ubuntu] Next steps (run manually, then update this script once confirmed):"
echo ""
echo "  export HDTN_SOURCE_ROOT=${WORKDIR}/HDTN"
echo "  cd \${HDTN_SOURCE_ROOT}"
echo "  mkdir -p build && cd build"
echo "  cmake .."
echo "  make -j\$(nproc)"
echo "  sudo make install"
echo ""
echo "[setup-ubuntu] Note: on t3.medium (2 vCPU), 'make -j\$(nproc)' uses -j2."
echo "  This will be slow (potentially 20-40+ min) but should not OOM at 4GB RAM."
echo "  If it does OOM, retry with 'make -j1' (slower but lower peak memory)."
echo ""
echo "[setup-ubuntu] After a successful build, binaries should appear under:"
echo "  \${HDTN_SOURCE_ROOT}/build/module/hdtn_one_process/"
echo "  \${HDTN_SOURCE_ROOT}/build/common/bpcodec/apps/ (bpgen-async, bpsink-async)"
echo ""
echo "[setup-ubuntu] Fill those real paths into ../scripts/run_hdtn_test.sh"
echo "  (HDTN_BIN / BPGEN_BIN / BPSINK_BIN) once confirmed."

echo "[setup-ubuntu] dependency install complete. Build step left as manual/TODO."