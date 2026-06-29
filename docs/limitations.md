# Limitations（誠實聲明）

這份文件存在的目的：在動手做實驗之前，先把每個環境「實際上是什麼」與
「容易被誤稱為什麼」寫清楚，避免文章發布後被讀者（合理地）挑戰方法論。

## 1. 沒有任何環境是 bare-metal native Linux

| 環境 | 容易被誤稱為 | 實際上是 |
|---|---|---|
| Cloud Linux VM | "native baseline" | Cloud hypervisor 上的 guest VM |
| Apple `container` CLI | "一般 container" | per-container 的 lightweight VM（Virtualization.framework） |
| Docker Desktop on macOS | "跟 Linux 上的 Docker 一樣" | 多 container 共享 1 個 Linux VM，VM 本身跑在 Apple Silicon 的 Virtualization.framework 之上 |
| macOS native build（若做） | "native baseline" | Darwin userspace，不是 Linux，網路堆疊不同 |

真正的 bare-metal Linux 基準（NASA 報告中的概念）在本實驗中**不存在**。
如果之後拿到實體 Linux 機器或 Raspberry Pi，才會有更接近的對照組。

## 2. Apple `container` CLI vs Docker Desktop 不是「container vs VM」的比較

兩者都是虛擬化方案，差別在於虛擬化的*粒度*：

- Docker Desktop：1 個共享 Linux VM，多個 container 在裡面用 namespace/cgroup 隔離
- Apple `container`：每個 container 各自一個 lightweight VM，VM 之間天生網路隔離

因此本實驗比較的是兩種**虛擬化哲學**（shared-VM vs per-container-microVM），
不是「有沒有虛擬化」的比較。文章與圖表中避免使用「container vs VM」這種
會誤導讀者的標籤。

## 3. `tc netem delay` 只模擬 propagation delay 的尺度

- 地月平均單程光行時間約 1.3 秒，本實驗用 `tc delay 1300ms` 作為**尺度參考**，
  不是完整的月球通訊鏈路模擬。
- 真實月球鏈路還包含：天線追蹤、訊號衰減、contact window 限制、
  Doppler shift、可能的隨機抖動（jitter）。這些都不在本實驗範圍內。
- `tc loss` 模擬封包遺失率，但深空鏈路真實的錯誤模式（burst error 等）
  比單純 random loss 複雜，本實驗不嘗試精確建模。

## 4. Normalized Efficiency 指標的限制

```text
Normalized Efficiency = HDTN Goodput / iperf3 Baseline Throughput
```

這個指標用來抵消不同環境硬體本身的差異，但仍有限制：

- iperf3 測的是 raw TCP/UDP throughput，HDTN goodput 包含 bundle 封裝、
  storage I/O、ZeroMQ 事件等額外開銷，兩者不是同一層的工作量，
  比值只能當作**相對效率的粗略參考**，不是嚴格的「效率百分比」。
- 不同環境的 CPU 架構不同（Apple Silicon vs Cloud VM 的 x86/ARM），
  即使 normalized 後，仍可能反映 CPU 微架構差異而非單純虛擬化開銷。

## 5. 樣本量與統計檢定力

- 個人實驗環境資源有限，每組測試重複次數（建議 3 次取 median）
  遠少於正式 benchmark 應有的樣本量。
- 本實驗的數字適合用來觀察**趨勢方向**（例如「延遲增加後 goodput 下降」），
  不適合用來宣稱精確的效能百分比差異有統計顯著性。

## 6. 這個實驗想證明、以及不想證明的事

**想觀察**：
- 不同虛擬化模型下，HDTN 的相對效率趨勢是否與 NASA 報告觀察到的方向一致
  （虛擬化層可能造成顯著效能損失）
- 地月級延遲對 HDTN goodput 的影響量級

**不宣稱**：
- 「Apple container 比 Docker 快 / 慢 X%」這種精確結論
- 完整重現 NASA TM-20220011407 的測試結果
- 任何環境代表「太空任務實際會用的硬體」
  
## 7. `tc netem` 套用的網路介面，依 topology 而不同

**這點容易出錯，務必先確認流量實際走哪個介面，再決定 `tc` 套在哪裡：**

- **single process topology（Phase 0/1）**：bpgen、hdtn-one-process、bpsink
  三個 process 都在同一台機器上，彼此用 `127.0.0.1`（loopback）通訊。
  `tc netem` 必須套在 **`lo`**，套在實體網卡（如 `eth0`/`ens5`）上
  **不會影響流量**，因為流量根本沒有經過那張卡。
- **multi-container topology（Phase 2）**：bpgen/hdtn/bpsink 分別在不同
  container 或 VM 裡，流量才會真正走對外（或 container 間）的網路介面，
  這時 `tc` 才要套在實際的介面上（container 內部視角的 `eth0`，或
  Apple container CLI 配發的介面，需另外確認）。

每次套用前，先用 `ip link show` 或在 HDTN log 裡確認連線用的是
`127.0.0.1` 還是其他 IP，再決定要套在哪張介面。


## 8. C1 vs C1-D 的劇烈落差，主因是 pipeline window 太小，不是「HDTN 在高延遲下表現差」

2026-06-28 實測：C1（0ms delay）量到 ~7267 Mbit/s；C1-D（1300ms owlt，
即 RTT≈2.6s）只量到 ~1.68 Mbit/s，差距超過 4000 倍。

**這個落差幾乎完全由 `maxNumberOfBundlesInPipeline: 5`（bpgen outduct
config）造成，不是延遲本身對「資料傳輸」造成的直接影響。**

- bpgen log 出現大量 `Unable to send a bundle for 3 seconds on the
  outduct.. retrying in 1 second`，這代表 5 個 unacked bundle 的窗口
  在 RTT≈2.6s 下很快被填滿，bpgen 必須停下來等 ack 才能送下一批。
- 這正是 Bandwidth-Delay Product（BDP）問題的具體案例：
  `BDP = Bandwidth × RTT`。窗口大小（5 bundle × 1MB = 5MB）遠小於
  「填滿 2.6 秒 RTT 所需的資料量」，所以 throughput 被窗口大小卡死，
  而非被網路頻寬或 CPU 卡死。
- **這代表 C1 vs C1-D 的比較目前回答的是「pipeline window 在地月延遲下
  夠不夠用」，不是「HDTN 軟體本身在高延遲下的效能上限」**。如果要量
  HDTN 在高延遲下「理論上能達到的」throughput，需要先把
  `maxNumberOfBundlesInPipeline`／`maxSumOfBundleBytesInPipeline`
  調大到能填滿 BDP 的程度，再重新測一次，兩個數字都要放進文章，
  並明確說明各自回答的是哪個問題。
- 這也是為什麼 LTP（Licklider Transmission Protocol）會為深空鏈路
  特別設計 session/checkpoint 機制而不是單純的小窗口 stop-and-wait——
  STCP 在這次實驗中的行為，某種程度示範了「沒有針對高延遲設計的
  convergence layer」會遇到的真實問題。之後若另開 LTP 實驗，這裡的
  C1-D 數字可以作為「STCP baseline」的對照組。


## 9. Measurement Pitfall Case Study：B2（650ms delay）的 STCP source ACK 語義與 post-generation drain

2026-06-28 實測，B2（650ms loopback delay、STCP、window=800、1MiB bundle）
原始數據看起來異常：bpgen 回報 `totalBundlesSent=811, totalBundlesAcked=811`，
但 bpsink 最終只收到 88 個 bundle（`Rx Count=88, Total bytes Rx=92274688`，
精確等於 88×1,048,576）。bpsink 的 `Total Rate` 統計 88 筆樣本中 87 筆
完全相同（1.6777 Mbit/s，對應每 5 秒交付 1 個 1MiB bundle）。

這個現象經過完整的源碼比對與時間線重建後，**已排除以下幾個曾經懷疑的原因**：

- **不是 cumulative average 的數學假象**：經查 `BpSinkPattern::TransferRate_TimerExpired()`
  原始碼（`common/bpcodec/src/app_patterns/BpSinkPattern.cpp:582-609`），
  `Total Rate` 是用「這次與上次 timer 觸發之間的差值」除以「真實時間差」算出的
  interval rate，不是從程式開始累積的平均值。這個 timer 固定每 5 秒觸發一次
  （`m_timerTransferRateStats.expires_from_now(boost::posix_time::seconds(5))`）。
- **不是 netem queue drop**：測試後查 `tc -s qdisc show dev lo`，
  `dropped=0, overlimits=0, requeues=0, backlog=0b 0p`，沒有任何封包遺失或
  佇列堆積的痕跡（但這是事後查的，之後重跑應該在測試**進行中**就持續取樣）。
- **`totalBundlesAcked=811` 不等於 bpsink 應用層收到的數量**：查
  `common/stcp/src/StcpBundleSource.cpp` 第 370 行，`m_totalBundlesAcked`
  是在 `StcpBundleSource::HandleTcpSend()` 這個 TCP async send 成功回調裡
  遞增的（`m_totalBundlesAcked.fetch_add(1, std::memory_order_relaxed)`），
  這是**STCP outduct/source 端 TCP 寫入完成的本地計數器**，跟「bpsink
  應用層真正處理完這個 bundle」是完全不同的兩個語義層級。`811` 和 `88`
  不需要相等，因為它們衡量的不是同一件事。

**已確認的真正原因（時間線重建）**：

`scripts/run_hdtn_test.sh` 是用前景（foreground，沒有背景 `&`）執行
`bpgen-async`，腳本會卡在這一行直到 `bpgen-async` 完整退出才往下走
（sleep 5 → kill bpsink → kill hdtn）。`bpgen-async` 在 `--duration=60`
時間到了之後，並不會立刻退出——它進入 `StcpBundleSource` 的解構子，
逐個等待 pipeline 裡剩餘的 unacked bundle 完成 TCP send（bpgen log
可見 `StcpBundleSource destructor waiting on N unacked bundles`，N
從 800 附近一路遞減到 1）。在 650ms delay 下，這個排空過程實測花了
**超過 5 分鐘**（使用者實際等待時間確認），遠超腳本原本假設的
60+12≈72 秒總長。

bpsink 在這整段排空期間沒有被 kill，持續存活並記錄，所以 88 筆
`Total Rate` 樣本其實涵蓋的是這段「bpgen 已停止產生新資料，但
outduct 仍在排空舊資料」的 drain 階段，不是 60 秒 generation
window 內的數據。

**仍未解決、刻意不下結論的部分**：

為什麼 bpsink 在這段 drain 期間，交付速率精確卡在「每 5 秒 1 個
bundle」，而不是更接近 650ms 延遲（RTT≈1.3秒）理論上應該允許的
「每 5 秒 3-4 個」？目前沒有找到能解釋這個精確比率的機制。
**不宣稱**這是 STCP 在高延遲下的正常/預期行為，也不宣稱這是某個
已識別的 HDTN egress 限速機制——這是一個記錄下來但尚未完全解釋
的觀察現象，留待之後有時間再深入 STCP/TCP 互動細節時查證
（例如查 TCP-level congestion window、socket send buffer 大小、
`StcpBundleSink` 的 `numRxCircularBufferElements` 緩衝行為，
或 STCP 是否有額外的 per-send 等待邏輯）。

**對實驗方法論的影響**：

這個案例的教訓不是「HDTN 在 650ms 延遲下很慢」，而是三個更根本的
方法論陷阱：

1. `bpgen --duration` 只控制「產生資料的時長」，不是「整個測試的
   wall-clock 總長」——如果 outduct 排空時間很長，腳本實際執行時間
   會遠超預期，且這個差異在高延遲下會被放大
2. 不同 component（bpgen / hdtn / bpsink）的 ack/sent/received
   計數器分屬不同協定層級，不能假設它們應該相等或可以互相驗證
3. 量測 throughput 時，「generation window 內的速率」跟「drain
   phase 的速率」是兩個不同的指標，混在一起看會產生誤導性的結論

**後續實驗的具體調整**：

- 之後跑 B3-B6（更高延遲）之前，要先確認 `bpgen-async` 排空時間
  是否會隨延遲線性增長到不可接受的程度（1300ms 延遲下可能要等
  10 分鐘以上）
- `run_hdtn_test.sh` 應該記錄完整時間線（hdtn 啟動、bpsink 啟動、
  generation 開始、duration 到達、bpgen 完整退出、kill 時刻），
  而不是只假設總長是 `duration + 12秒`
- `parse_results.py` 計算 goodput 時，應該區分「generation-window
  goodput」與「wall-clock 總 delivered goodput」兩個指標，不能
  只用一個數字代表全部
- 這個案例本身可以直接寫進部落格文章，當作「個人實驗室如何踩坑、
  如何用源碼交叉驗證排除錯誤假設」的一個獨立小節，比單純呈現
  benchmark 表格更有技術深度

## 10. Smoke test 排查記錄：`--bundle-rate=0` 讓短測試也會卡進長時間 destructor drain，且 egress ACK 語義陷阱在小規模下同樣存在

2026-06-28，為了驗證 `run_hdtn_test.sh` v2（timeout/metadata/timeline 機制）
本身是否正常運作，設計了一系列 smoke test（極短 duration、0ms 延遲），
結果暴露出三個疊加的問題，記錄完整排查過程供之後參考。

### 現象

第一次 smoke test（`SMOKE`，duration=5s，使用主實驗的 window=800 config）：
`bpgen_exit_status=timeout_killed`，bpsink 完全沒收到任何 bundle
（`Rx Count=0`）。改用小 window（5）後（`SMOKE-smallwin-v2`），依然
`timeout_killed`、`Rx Count=0`，但 HDTN 內部統計顯示 ingress 確實收到
2 個 bundle、egress 也確實 acked 2 個——資料明明在 HDTN 內部流動，
卻完全沒有抵達 bpsink 應用層。

### 排查過程中曾經懷疑、後來排除的假說

- **Security Group 設定錯誤**：排除。整條路徑都是 `127.0.0.1` loopback
  通訊，不經過任何網卡，Security Group 完全不影響 instance 內部的
  process 間通訊。
- **`maxSumOfBundleBytesInPipeline` 設太小**：曾經真實觸發過一次
  （`outduct-stcp-port4556-smoke.json` 初版誤設為 5MB，小於
  `maxBundleSizeBytes × 2`，導致 bpgen 在 config 驗證階段直接
  fatal 退出）。修正後（設為 25MB）此問題消失，但 smoke 仍然失敗，
  證明這不是主因，只是疊加的另一個獨立 bug。
- **contact plan 的 `rateBitsPerSec: 0` 代表「contact 速率為 0」，
  導致 egress 不送資料**：直接用 C1（成功傳輸 56,979 個 bundle 的
  baseline）對照排除——C1 的 hdtn log 裡同樣出現
  `setting rate to 0 bps for new contact` 這一行，證明這個數值
  在當前 HDTN 版本中應該是「無限速率」的語義，不是「停止傳輸」，
  跟這次 smoke 失敗無關。
- **HDTN 的 link/route 在某個隱藏的時間窗口後會自動 DOWN**：
  最初观察到 link UP 後大約 21 秒就 DOWN，懷疑跟 contact plan 的
  `endTime` 有關，但後續對照發現這個現象沒有獨立查證出根因，
  且後續測試顯示不是主要瓶頸，故不繼續深究，標記為未完全解釋的
  次要觀察。

### 已確認的真正原因（兩層疊加）

1. **`--bundle-rate=0` 讓 `bpgen-async` 以「盡可能快」的方式立即
   填滿整個 pipeline window，不論 `--duration` 設多短**。即使
   window 縮小到 5，5 秒的生成時間仍然來不及讓這些 bundle 完整走完
   「送出 → TCP ack → STCP 應用層處理」全程，bpgen 在 duration
   結束後立刻進入 `StcpBundleSource` destructor，逐個等待 in-flight
   bundle 被 ack——這跟本文件第 9 節（B2 案例）是同一族問題，
   只是這次在更短的時間尺度上重現。

2. **`DRAIN_SEC` 太短，導致 bpsink 應用層還沒來得及把已經在 TCP 層
   被 egress 標記為 acked 的 bundle 真正處理完，測試就被結束**。
   實測對照：
   - `DRAIN_SEC=3`：bpsink `Rx Count=0`（即使 egress 端
     `totalBundlesAcked=2`）
   - `DRAIN_SEC=15`：bpsink `Rx Count=3`，但 egress 端
     `totalBundlesAcked=4`——**仍然少 1 個，且 `bpgen_exit_status`
     依然是 `timeout_killed`**，代表 15 秒仍不是一個乾淨、完整的
     drain 窗口，只是緩解了部分症狀。

   這再次印證第 9 節已經記錄的結論：**STCP outduct 的
   `totalBundlesAcked`（TCP send 完成的本地計數器）與 bpsink
   應用層的 `Rx Count`（真正完成解析、計入統計的數量）是兩個
   不同協議層級的指標，不能假設兩者相等，即使在 0ms 延遲、
   極小規模的測試裡也會出現落差**。

### 對實驗方法論的影響

這次排查的教訓比表面現象更重要：**不要用主實驗的高壓參數
（`bundle-rate=0`、大 window）直接拿來做 harness 的 smoke test**。
smoke test 應該測試「腳本的 process 生命週期管理機制本身是否正常」，
不應該同時把「HDTN/STCP 在高壓 workload 下的真實排空行為」這個
複雜變數也捲進來——這會讓 smoke test 的失敗原因難以判斷，
正如這次花了多輪排查才逐步排除掉幾個無關的假說。

### 後續修正（已完成，2026-06-28）

`run_hdtn_test.sh` 新增了兩個環境變數：

- `BUNDLE_RATE`：取代寫死的 `--bundle-rate=0`，smoke test 可用明確低速率
- `PAYLOAD_BYTES`：可覆寫 bundle 大小，smoke test 不用被迫沿用主實驗的
  1MiB payload

驗證過程的關鍵數據點（同一台機器、同樣 window=5、0ms 延遲，逐步排除變數）：

| Test ID | bundle_rate | payload | bpgen_exit_status | bpsink Rx Count | wall_clock_total_sec |
|---|---|---|---|---|---|
| SMOKE-smallwin-v2 | 0 | 1MiB | timeout_killed | 0 | ~28 |
| SMOKE-drain15 | 0 | 1MiB | timeout_killed | 3（egress acked 4） | ~49 |
| SMOKE-rate1 | 1 | 1MiB | timeout_killed | 4（egress acked 5） | ~54 |
| SMOKE-rate1-grace60 | 1 | 1MiB | **exited_normally** | **6 = 6 = 6**（全部對上） | 71.9 |
| **SMOKE-light** | 1 | **64KiB** | **exited_normally** | **6 = 6 = 6**（全部對上） | **28.9** |

`SMOKE-light` 證實：把 `bundle_rate` 降到 1、payload 降到 64KiB（遠小於
主實驗的 1MiB），harness 本身（`timeout --kill-after`、`trap cleanup`、
`timeline.tsv`、`metadata.json`）完全沒有 bug，可以在 29 秒內乾淨跑完
並讓 bpgen 生成數量、HDTN 內部 sent/acked、bpsink 應用層 Rx Count
三者完全一致。**`SMOKE-light` 的參數組合（`BUNDLE_RATE=1`,
`PAYLOAD_BYTES=65536`，配合小 window config）正式定為 harness smoke
test baseline**，之後修改 `run_hdtn_test.sh` 都應該先用這組參數驗證
沒有破壞 process lifecycle，再進入正式的延遲矩陣測試。

Smoke test 的「通過」分兩層判斷：

- **Harness lifecycle 通過**：process 都正常啟動/收尾、
  metadata/timeline 格式正確、沒有殘留進程（即使 `Rx Count=0` 也可能
  屬於這一層，只代表 workload 太重，不代表腳本本身有問題）
- **Clean protocol 通過**：`bpgen_exit_status=exited_normally`
  且 bpsink `Rx Count` 等於 bpgen 實際生成的 bundle 數量，這才能視為
  一次「乾淨」的測量，可以放進正式的 summary.csv。`SMOKE-light` 是
  目前唯一同時通過兩層的 smoke 設定。

---

如果之後實驗過程中發現新的限制（例如某個環境的網路模型導致測試失真），
請隨時補充到這份文件，並在對應的 commit message 註明原因。

