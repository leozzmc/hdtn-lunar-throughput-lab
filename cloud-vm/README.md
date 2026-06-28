# Cloud Linux VM

架構定位：**Linux VM reference baseline**（不是 native bare-metal，
見 [`../docs/limitations.md`](../docs/limitations.md) 第 1 點）。

這是 Phase 0 最小可行版本要先跑的環境（最少變數、最容易確認
pipeline 是否跑通）。

## 前置確認

填入 `../docs/environment-matrix.md`：

```bash
cat /etc/os-release
nproc
free -h
uname -m   # 確認架構 x86_64 / aarch64
```

## 檔案

| 檔案 | 用途 | 狀態 |
|---|---|---|
| `setup-ubuntu.sh` | 安裝 build 依賴、clone 並 build HDTN | 骨架 |
| `run-native.sh` | 直接在 VM 上跑 HDTN process（不經 container） | 骨架 |
| `run-docker.sh` | 在 VM 上裝 Docker，跑 container 化的 HDTN（對照組 C2/C3） | 骨架 |

## Phase 0 執行順序

```bash
# 1. 環境設置與 build
./setup-ubuntu.sh

# 2. 確認 HDTN 跑得起來（手動跑一次，先不套用延遲）
./run-native.sh --test-id C1 --payload-mb 1 --duration 60

# 3. 套用地月延遲後再跑一次
../scripts/setup_tc_delay.sh eth0 1300
./run-native.sh --test-id C1-D --payload-mb 1 --duration 60
../scripts/clear_tc.sh eth0
```

達成 Phase 0 完成標準後（見 `../docs/experiment-design.md`），
才繼續做 Docker on Cloud VM（C2/C3）以及切到 Docker Desktop / Apple
container CLI。

## 已知待確認事項

- [ ] 雲端 instance 的網路介面名稱（通常是 `eth0`，但部分 provider
      用 `ens5` 等命名，需要用 `ip link` 確認）
- [ ] Security Group / Firewall 是否需要額外開放 port 4556/4558
      （即使是同一台機器內的 process 通訊，部分雲端防火牆預設規則
      仍可能影響 loopback 之外的介面）
- [ ] Instance 規格是否足以呈現有意義的差異（太小的 instance
      可能讓所有環境都被 CPU/網路上限卡住，看不出虛擬化層的差異）
