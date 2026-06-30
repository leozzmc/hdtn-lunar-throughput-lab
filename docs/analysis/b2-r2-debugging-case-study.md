# B2/B2-r2 Debugging Case Study

> 2026-06-28。這份文件記錄一輪從「異常數字」到「測量方法論修正」的完整
> 排查過程，目的是固定下這輪釐清的細節，避免之後跑 Phase 1 矩陣
> （B3-B6）時不小心把這些教訓忘掉、重複犯同樣的方法論錯誤。
>
> 完整的逐步排查記錄（含每次假說提出、查證指令、原始 log）見
> `docs/limitations.md` 第 9、10 節；這份文件是濃縮後的工程筆記，
> 方便快速回顧結論與關鍵區分。

## 1. 初始異常（B2）

- 設定：650ms loopback delay（`tc netem` 套在 `lo`）、STCP、
  `maxNumberOfBundlesInPipeline=800`、1MiB bundle、`bundle_rate=0`
- 觀察到的現象：bpsink 的 `Total Rate` 樣本反覆顯示約 `1.6777 Mbit/s`
- 數學對應：`1 MiB × 8 / 5 sec ≈ 1.6777 Mbit/s`，也就是「每 5 秒
  reporting interval 剛好送達 1 個 1MiB bundle」

## 2. 已排除的假說（依序，每個都有對應的查證證據）

| 假說 | 排除方式 |
|---|---|
| `Total Rate` 是 cumulative average 造成的數學假象 | 查 `BpSinkPattern::TransferRate_TimerExpired()` 源碼，確認是用「跟上次 timer 觸發的差值」算出的 interval rate，不是累積平均 |
| `tc netem` queue 被打爆、封包遺失 | `tc -s qdisc show dev lo` 顯示 `dropped=0, overlimits=0, backlog=0` |
| Security Group 設定錯誤 | 整條路徑都是 `127.0.0.1` loopback，不經過任何網卡，Security Group 不影響 instance 內部通訊 |
| contact plan `rateBitsPerSec=0` 導致 egress 不送資料 | 用 C1（成功傳輸 56,979 bundle 的 baseline）對照，C1 的 hdtn log 同樣有 `setting rate to 0 bps for new contact`，證明這個數值不是問題根因 |
| HDTN config 驗證失敗（`maxSumOfBundleBytesInPipeline` 太小） | 曾經真實觸發過一次（smoke config 誤設小於 `maxBundleSizeBytes × 2`），修正後問題仍在，證明這只是另一個獨立的小 bug，不是主因 |
| `bpgen totalBundlesAcked` 等於 bpsink 應用層真正收到的數量 | 查 `common/stcp/src/StcpBundleSource.cpp` 第 370 行附近的 `HandleTcpSend()`，確認 `m_totalBundlesAcked` 是在 TCP `async_write` 成功回調裡遞增，屬於 STCP outduct/source 端的本地計數器，跟「bpsink 應用層真正處理完這個 bundle」是不同協議層級，兩者不需要相等 |

## 3. 真正的測量工具（harness）缺陷

- 舊版 `run_hdtn_test.sh` 用前景（無背景 `&`）執行 `bpgen-async`，
  且沒有任何 wall-clock timeout 保護
- `bpgen --duration` 只控制「產生新 bundle 的時長」，不代表 process
  的總存活時間——duration 到期後，`bpgen-async` 會進入
  `StcpBundleSource` 的解構子，逐個等待 pipeline 裡剩餘的 unacked
  bundle 完成 TCP send，這個排空（drain）過程在高延遲下可能耗費
  數分鐘
- 因為腳本前景等待 `bpgen-async` 完整退出才會往下走（kill bpsink/hdtn），
  使用者實際等待的 wall-clock 時間會遠超「`--duration` 設定值」
  暗示的長度（B2 案例實測超過 5 分鐘）

## 4. v4 harness 的修正

- 用 GNU `timeout --kill-after` 取代手寫的 process polling，給
  `bpgen-async` bounded wall-clock 執行時間
- 新增 `timeline.tsv`，記錄每個關鍵階段（hdtn/bpsink/bpgen 啟動、
  bpgen 結束、drain 開始/結束、bpsink/hdtn 停止）的 timestamp
- 新增 `trap cleanup`（`EXIT`/`INT`/`TERM` 分開處理），避免任何
  退出路徑留下背景的孤兒程序
- 新增 `metadata.json`，記錄這次測試的實際參數與結束狀態
  （`bpgen_exit_status`、`bpgen_return_code`、`wall_clock_total_sec` 等）
- 新增 `BUNDLE_RATE`、`PAYLOAD_BYTES` 環境變數，讓 smoke test 可以
  用遠低於主實驗壓力的設定，驗證 harness 本身的 process lifecycle，
  不被 HDTN/STCP 在高壓 workload 下的真實排空行為干擾判讀

## 5. Smoke test 驗證結果（証實 harness 本身沒有 bug）

| Test ID | bundle_rate | payload | delay | bpgen_exit_status | bpsink Rx Count | 對帳 |
|---|---|---|---|---|---|---|
| SMOKE-light | 1 | 64KiB | 0ms | exited_normally | 6 | bundle_count=6=Rx Count（全部對上） |
| SMOKE-light-delay650 | 1 | 64KiB | 650ms | exited_normally | 6 | bundle_count=6=Rx Count（全部對上） |

兩組都在合理時間內（29-79 秒）乾淨完成，證實 v4 harness 機制本身
（timeout、cleanup、timeline、metadata）在 0ms 與 650ms 延遲下都
正常運作，之前的失敗（`SMOKE`、`SMOKE-smallwin-v2` 等）是 smoke
workload 設計不合理（沿用主實驗的高壓參數），不是腳本邏輯的 bug。

## 6. B2-r2：用乾淨 harness 重跑原始異常設定

設定與 B2 完全相同（650ms delay、STCP、window=800、1MiB bundle、
`bundle_rate=0`），差別只在用 v4 harness 跑、給足夠的
`BPGEN_GRACE_SEC=300`：

- `bpgen_exit_status=exited_normally`（**未被 timeout 打斷**，這是
  跟原始 B2 最關鍵的差異——原始 B2 沒有這個驗證，無法排除
  「異常是不是 timeout 副作用」這個可能性）
- `tc -s qdisc`：`dropped=0, overlimits=0, backlog=0`
- 三端最終統計完全對帳：
  `bpgen totalBundlesSent=25` = `bpgen totalBundlesAcked=25` =
  `HDTN m_ingressBundleCountEgress=25` = `HDTN egress totalBundlesAcked=25`
  = `bpsink Rx Count=25`

## 7. B2-r2 觀察到的現象（精確措辞，避免過度宣稱）

bpsink log 記錄了 **25 筆 positive delivery-rate 樣本，全部約
1.6777 Mbit/s**，乾淨復現了原始 B2 的固定 positive-interval cadence。

**但這不代表整場測試每 5 秒都送達 1 個 bundle**。查證
`TransferRate_TimerExpired()` 源碼確認：這個 timer 只在「跟上次相比
有任何 byte/bundle 變化」時才印 log，沒有變化的窗口會被直接跳過、
不留記錄。這次測試 wall-clock 總長 264.6 秒，理論上對應約 53 個
5 秒窗口，但只記錄到 25 筆 positive 樣本——代表測試期間存在數量相當
的「完全沒有 bundle 送達」的靜默窗口。

**目前能確認的、比較精確的描述**：

> 在這次 650ms loopback delay 的 STCP 測試中，每一個有記錄到的
> positive delivery interval，恰好都送達 1 個 1MiB bundle；同時
> 測試期間存在數量相當的靜默窗口。這代表傳輸呈現某種間歇性
> （intermittent）模式，不是穩定連續的「每 5 秒 1 個」。

機制本身**仍未解釋**，不宣稱是 STCP 在高延遲下的正常/預期行為，
也不宣稱是某個已識別的 HDTN egress 限速機制。可能跟 STCP
send/receive buffering、TCP 在 loopback netem delay 下的行為、
HDTN source/sink 的 event loop，或其他尚未定位的交互作用有關。

## 8. 三個容易混淆、必須分開報告的速率指標

`parse_results.py` 修正前，這三個語義不同的數字曾經被混在同一個
`hdtn_goodput_mbps` 欄位裡：

| 指標 | 算法 | B2-r2 數值 | 代表的意義 |
|---|---|---|---|
| `hdtn_interval_rate_avg_mbps` | bpsink positive interval 樣本平均 | 1.6777 | 「有送達時」的瞬時速率，**不是**整場平均 |
| `hdtn_delivered_goodput_mbps` | 總送達 bytes ÷ 設定的 generation duration（60s） | 3.4953 | 以「測試設計時長」為分母的 goodput |
| `hdtn_wall_goodput_mbps` | 總送達 bytes ÷ 真實 wall-clock 總時長（264.6s） | 0.7926 | 以「使用者實際等待時間」為分母的 goodput，**最貼近「這個設定下實際能用的速度」** |

這三個數字差了 4 倍以上，任何一個被誤用成「B2-r2 的 throughput」
都會讓跨延遲組的比較失真。

## 9. 關鍵區分（之後跑 B3-B6 時要記住，避免重蹈覆轍）

- **positive interval rate ≠ generation-window goodput ≠
  wall-clock goodput**——三者衡量不同的事，不能只看一個數字
- **`bpgen totalBundlesAcked` ≠ application-layer delivery**——
  前者是 STCP outduct 的 TCP send 完成計數，後者才是 bpsink 真正
  處理完的數量，兩者屬於不同協議層級
- **`bpgen_exit_status=timeout_killed` 的結果 = incomplete lower
  bound**——這類數據只能當下限參考，不能當乾淨測量值使用，
  `parse_results.py` 已自動在 notes 欄位標記
  `INCOMPLETE_LOWER_BOUND(bpgen_timeout_killed)`
- **bpsink 的 idle 5 秒窗口不會印出 rate sample**——只看「有印出的
  樣本數量」會低估真實的測試時長涵蓋範圍，必須對照 `timeline.tsv`
  的真實 wall-clock 長度，才能正確判斷測試期間的傳輸節奏是連續還是
  間歇

## 10. 尚待解答的問題

為什麼這個 650ms delay + STCP + window=800 的組合下，positive
delivery interval 反覆呈現「恰好 1 個 1MiB bundle」這個固定模式？
這個現象已經用兩次獨立測試（原始 B2、B2-r2）重現，可信度高，但
根本機制仍未查明。留待之後有時間深入 STCP/TCP 互動細節（例如
TCP congestion window、socket send buffer、`StcpBundleSink` 的
`numRxCircularBufferElements` 緩衝行為）時再查證。
