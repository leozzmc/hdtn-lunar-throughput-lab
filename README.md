# HDTN Lunar Throughput Lab

個人可重現的 NASA HDTN（High-rate Delay Tolerant Networking）throughput 實驗環境，
比較不同虛擬化模型（Apple `container` CLI、Docker Desktop、Cloud Linux VM）
在模擬地月延遲（`tc netem`）條件下對 DTN bundle forwarding throughput 的影響。

延伸閱讀（部落格系列前兩篇）：

1. [為什麼太空網路需要 DTN？從 TCP/IP 的限制到深空網路](https://leozzmc.github.io/posts/7d41a775.html)
2. [NASA HDTN 架構解析：太空 DTN 如何真正運作？](https://leozzmc.github.io/posts/25763fe7.html)

## 這個實驗在做什麼

上一篇文章拆解了 HDTN 的軟體架構（Ingress / Storage / Scheduler / Router / Egress）。
這個 repo 把架構理解推進到可測量的層面：

> 當 HDTN 被放進不同的虛擬化層、container runtime，以及高延遲鏈路時，
> 它的吞吐量會怎麼變？

## ⚠️ 這個實驗「不是」什麼（誠實聲明）

請先讀過再看任何數字：

- **這不是 NASA TM-20220011407 的完整重現。** NASA 的測試使用真實的 ISS-like
  4-box topology、bare-metal hardware、KVM、LXC。本實驗使用個人可取得的硬體
  （MacBook + Cloud VM），規模與精確度都遠小於官方測試。
- **沒有任何一個環境是「native bare-metal Linux」。** 包括 Cloud VM ——
  它是 cloud hypervisor 上的 Linux VM，不是 bare-metal。本文一律稱它為
  **Linux VM reference baseline**，不稱為 native。
- **Apple `container` CLI 不是傳統 container。** 它是 per-container
  lightweight VM（透過 Virtualization.framework），跟 Docker Desktop
  的「多個 container 共享一個 Linux VM」是不同的架構模型。比較這兩者，
  本質上是在比較兩種虛擬化哲學，不是「container vs VM」。
- **`tc delay 1300ms` 只模擬 propagation delay**，不是完整的地月通訊鏈路
  模擬（沒有模擬天線追蹤、訊號衰減、contact window 等其他因素）。
- 詳細限制與每個環境的定位，見 [`docs/limitations.md`](docs/limitations.md)。

完整方法論見 [`docs/experiment-design.md`](docs/experiment-design.md)。

## 環境矩陣總覽

| 環境 | 實際架構 | 本文稱呼 |
|---|---|---|
| Docker Desktop on macOS | 多 container 共享 1 個 Linux VM | Docker Desktop（shared VM 模型） |
| Apple `container` CLI | 每個 container 各自一個 lightweight VM | Apple Container（per-container microVM 模型） |
| Cloud Linux VM | Cloud hypervisor 上的單一 Linux VM | Linux VM reference baseline |

完整環境設置細節見 [`docs/environment-matrix.md`](docs/environment-matrix.md)。

## 目錄結構

```text
hdtn-lunar-throughput-lab/
  docs/                   實驗設計、環境矩陣、限制聲明、參考資料
  docker/                 Docker Desktop 用的 Dockerfile / compose
  apple-container/        Apple container CLI 用的 build / run script
  cloud-vm/                Cloud Linux VM 的 setup / run script
  configs/                HDTN / bpgen / bpsink 設定檔（contact plan 等）
  scripts/                跨環境共用：tc netem、iperf baseline、結果收集、畫圖
  results/raw/<env>/      各環境的原始輸出
  results/processed/      整理後的 summary.csv
  pcaps/<env>/            tcpdump 封包紀錄
  charts/                 最終圖表
```

## 快速開始

每個環境的詳細步驟在各自資料夾的 README：

- [`docker/README.md`](docker/README.md)
- [`apple-container/README.md`](apple-container/README.md)
- [`cloud-vm/README.md`](cloud-vm/README.md)

所有環境共用的延遲模擬、baseline 測試、結果收集腳本都在 [`scripts/`](scripts/)，
細節見 [`scripts/README.md`](scripts/README.md)。

## 實驗矩陣（Phase 0 最小可行版本）

完整矩陣見 experiment-design.md，這裡先列 Phase 0：

| ID | 環境 | Topology | Delay |
|---|---|---|---|
| C1 | Cloud Linux VM | single process | 0ms |
| C1-D | Cloud Linux VM | single process | 1300ms |

跑通 Phase 0 之後才擴展到 Docker Desktop / Apple container 與更多 delay/loss 組合。

## 授權與引用

實驗腳本與結果採 MIT License（見 [`LICENSE`](LICENSE)）。
NASA HDTN 原始碼與文件版權屬於 NASA，請參閱
[nasa/HDTN](https://github.com/nasa/HDTN) 之授權條款。
