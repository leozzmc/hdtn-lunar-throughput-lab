# Scripts

跨環境共用的腳本。每個環境（docker / apple-container / cloud-vm）下面
的 README 會說明該環境特有的 build/run 步驟，並呼叫這裡的共用腳本。

## 使用順序

1. `run_iperf_baseline.sh` — 先取得該環境的 raw network throughput，
   作為 normalized efficiency 的分母
2. `setup_tc_delay.sh` — 套用模擬延遲/遺失，跑完一組測試後用
   `clear_tc.sh` 清除
3. `run_hdtn_test.sh` — 啟動 bpgen → hdtn → bpsink，收集 goodput
4. `collect_metrics.sh` — 收集 CPU / memory / pcap，整理成單次測試的結果
5. 全部測試跑完後，用 `parse_results.py` 把 `results/raw/<env>/`
   底下的原始輸出整理進 `results/processed/summary.csv`
6. `plot_results.py` 從 summary.csv 產生 `charts/` 底下的圖

## 腳本清單

| 腳本 | 用途 | 狀態 |
|---|---|---|
| `run_iperf_baseline.sh` | 起 iperf3 server/client 跑 baseline throughput | 骨架 |
| `setup_tc_delay.sh` | 套用 `tc netem delay/loss` | 骨架 |
| `clear_tc.sh` | 清除 tc qdisc 設定 | 骨架 |
| `run_hdtn_test.sh` | 啟動 bpgen/hdtn/bpsink 並收集 goodput | 骨架 |
| `collect_metrics.sh` | 收集 CPU/memory/pcap | 骨架 |
| `parse_results.py` | 整理 raw 輸出成 summary.csv | 骨架 |
| `plot_results.py` | 畫圖 | 骨架 |

「骨架」狀態的腳本目前只有參數解析與 TODO 註解，需要在對應環境裡
依實際 HDTN binary 路徑、config 路徑補完。

## 重要：`tc netem` 的作用介面

`tc netem` 是套在某個網路介面上的，不同環境的介面名稱不同：

- Cloud Linux VM：通常是 `eth0`，或測試用的 `veth`/`bridge` 介面
- Docker container 內：通常是 `eth0`（container 內部視角）
- Apple `container` CLI：每個 container 有自己的網路介面，需要在
  container 內部執行 `tc`，或視 Apple 提供的網路管理方式而定
  （見 `apple-container/README.md` 待補的實測結果）

第一次在新環境跑 `setup_tc_delay.sh` 前，先用 `ip link` 或 `ifconfig`
確認介面名稱，並把對應參數傳入腳本。
