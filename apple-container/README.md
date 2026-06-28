# Apple `container` CLI

架構定位：每個 container 各自一個 lightweight VM
（透過 Apple Virtualization.framework）。**不是傳統 container**，
見 [`../docs/limitations.md`](../docs/limitations.md) 第 2 點。

## 前置確認

- 需要 macOS 26+，Apple Silicon
- 安裝方式：到 [apple/container](https://github.com/apple/container)
  下載官方簽署的 installer

```bash
container --version
sw_vers   # 確認 macOS 版本，填入 ../docs/environment-matrix.md
```

如果 host macOS 版本不符，**這個環境組整組跳過**，並在文章與
`environment-matrix.md` 中明確說明原因，不要勉強用不支援的版本湊數據。

## 檔案

| 檔案 | 用途 | 狀態 |
|---|---|---|
| `build-image.sh` | build HDTN image 給 `container` CLI 用 | 骨架 |
| `run-single.sh` | topology: single（單 container 內跑 bpgen/hdtn/bpsink） | 骨架 |
| `run-multi.sh` | topology: multi（每個元件各自一個 lightweight VM） | 骨架 |

## 關鍵待確認事項（這組環境最大的不確定性）

- [ ] **網路模型**：Apple `container` 為每個 container 配發專屬 IP
      （不需要 port forwarding），但 multi-container 情境下，
      container 之間如何互相發現/連線，需要實測確認，可能跟
      Docker 的 bridge network 用法不同
- [ ] **`tc` 在 container 內是否可用**：lightweight VM 內的 Linux
      kernel 是否包含 `iproute2`/`tc`，需要實測；若不支援，
      可能要改成在 host 側用別的方式模擬延遲（例如針對
      container 的 IP 在 host 端套用 pf/dummynet，需另外研究）
- [ ] **multi-container topology 是否可行**：如果每個 container
      是獨立 lightweight VM，bpgen → hdtn → bpsink 之間的網路延遲
      本身（VM-to-VM）可能已經造成 baseline 偏移，需要先測
      "no-op" baseline（不開 HDTN，純粹 ping/iperf3 container 對 container）

## 執行步驟（待補完，實測後更新）

```bash
# 1. build image
container build --tag hdtn-lab:latest -f ../docker/Dockerfile.hdtn ../
# 注意：Dockerfile 是否能直接給 container CLI 用、語法是否完全相容
# 需要實測確認

# 2. 跑 single topology
./run-single.sh

# 3. 跑 multi topology
./run-multi.sh
```

如果這個環境在實測中卡住超過預期時間（例如網路模型搞不清楚、
build 不過），記得：

1. 把卡住的細節記錄到 `../docs/limitations.md`
2. 評估是否要先跳過這組、用 Docker Desktop + Cloud VM 兩組
   先把文章寫出來，Apple container 留作後續更新或單獨一節
