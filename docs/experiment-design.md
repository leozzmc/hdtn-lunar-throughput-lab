# Experiment Design

## 目標

觀察 NASA HDTN 在不同虛擬化模型、不同模擬延遲/中斷條件下的 throughput 變化，
並與 NASA TM-20220011407 中「虛擬化層可能造成顯著效能損失」的觀察方向做對照。

**這不是完整重現**，請先讀過 [`limitations.md`](limitations.md)。

## 建議的執行順序

不要一次做完整矩陣。建議順序：

1. **Phase 0**：單一環境（Cloud Linux VM）+ 單一 topology + 2 組 delay，
   確認整套 pipeline（build → run → tcpdump → 收集 metrics）能跑通
2. **Phase 1**：在同一環境內補完 baseline 與 delay/loss/disruption 矩陣
3. **Phase 2**：擴展到 Docker Desktop、Apple `container` CLI
4. **Phase 3**：跨環境比較、畫圖、撰寫文章

## Phase 0：最小可行版本

| ID | 環境 | Topology | Delay | Loss | Disruption |
|---|---|---|---|---|---|
| C1 | Cloud Linux VM | single process（bpgen→hdtn→bpsink） | 0ms | 0% | No |
| C1-D | Cloud Linux VM | single process | 1300ms | 0% | No |

完成標準：
- [ ] HDTN 在 Cloud VM 上 build 成功
- [ ] bpgen → hdtn → bpsink 跑出至少一個成功傳輸的 bundle
- [ ] tcpdump 抓到 port 4558 的封包並能用 Wireshark 開啟
- [ ] `tc netem delay 1300ms` 套用後，goodput 有可觀察的變化
- [ ] 上述兩組結果都寫進 `results/raw/cloud-vm/` 並能填入 summary.csv 格式

## Phase 1：完整延遲/中斷矩陣（單一環境內）

| Case | Delay | Loss | Disruption | 模擬意義 |
|---|---|---|---|---|
| B1 | 0 ms | 0% | No | baseline |
| B2 | 650 ms | 0% | No | 半地月尺度參考 |
| B3 | 1300 ms | 0% | No | 地月單程光行時間尺度參考 |
| B4 | 1300 ms | 0.1% | No | 低錯誤率深空鏈路 |
| B5 | 1300 ms | 1% | No | 較差鏈路 |
| B6 | 1300 ms | 0% | Yes（link down/up） | contact window / disruption |

每組：
- payload size：1 MB、10 MB 各跑一次
- duration：60 秒
- 重複 3 次，取 median

## Phase 2：跨環境矩陣

| ID | 環境 | Topology | Delay |
|---|---|---|---|
| D1 | Docker Desktop | single container | 0ms |
| D2 | Docker Desktop | multi-container | 0ms |
| D3 | Docker Desktop | multi-container | 1300ms |
| A1 | Apple `container` | single container | 0ms |
| A2 | Apple `container` | multi-container | 0ms |
| A3 | Apple `container` | multi-container | 1300ms |
| C1 | Cloud Linux VM | native process | 0ms |
| C2 | Cloud Linux VM | Docker containers | 0ms |
| C3 | Cloud Linux VM | Docker containers | 1300ms |

Topology 定義：

- **single（container/process）**：bpgen、hdtn、bpsink 都在同一個
  container 或同一個 VM 內的不同 process，測的是 HDTN 軟體本身的
  forwarding/storage overhead。
- **multi-container**：bpgen、hdtn、bpsink 分別在不同 container
  （或在 Apple container CLI 下，不同的 lightweight VM）裡，測的是
  跨虛擬化邊界的網路路徑對 throughput 的影響。

## Phase 0 之前：環境基準測試（每個環境都先跑一次）

| 測試 | 工具 | 目的 |
|---|---|---|
| CPU | `sysbench` 或 `stress-ng` | 確認各環境 CPU 能力差距 |
| Network | `iperf3` | 取得 normalized efficiency 的分母 |
| Disk | `fio` | 了解 Storage 模組可能的 I/O 瓶頸來源 |
| Memory | `free` / `vm_stat` / `top` | 監控 HDTN process 的記憶體使用 |

## 量測指標

每組測試記錄：

- `iperf_mbps`：該環境的 raw network baseline
- `hdtn_goodput_mbps`：bpsink 實際收到的有效資料率
- `normalized_efficiency`：`hdtn_goodput_mbps / iperf_mbps`
- `cpu_avg_pct`：測試期間平均 CPU 使用率
- `mem_rss_mb`：HDTN process 的 RSS 記憶體
- 是否有 bundle loss / retransmission（從 HDTN log 或 pcap 確認）

完整 schema 見 [`results/processed/summary.csv`](../results/processed/summary.csv)
的表頭定義。

## 输出產物

- `results/raw/<env>/`：每次測試的原始 log、iperf 輸出、HDTN log
- `results/processed/summary.csv`：整理後可直接畫圖的格式
- `pcaps/<env>/`：對應的 tcpdump 封包紀錄
- `charts/throughput_by_env.png`：各環境絕對 throughput 對照
- `charts/normalized_efficiency.png`：公平化後的效率對照
- `charts/delay_impact.png`：延遲對 goodput 的影響曲線

## 參考資料

見 [`references.md`](references.md)。
