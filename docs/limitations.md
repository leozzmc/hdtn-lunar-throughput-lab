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

---

如果之後實驗過程中發現新的限制（例如某個環境的網路模型導致測試失真），
請隨時補充到這份文件，並在對應的 commit message 註明原因。
