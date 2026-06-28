# Environment Matrix

每個環境用來實際填入版本號與硬體資訊。建立每個環境的測試前，先把這份表填好，
避免之後寫文章時忘記環境細節。

## 通用：HDTN 版本鎖定

所有環境必須使用**同一個 HDTN git commit**，否則跨環境比較沒有意義。

```bash
git clone https://github.com/nasa/HDTN.git
cd HDTN
git rev-parse HEAD   # 記錄這個 commit hash，填入下表
```

| 項目 | 值 |
|---|---|
| HDTN repo | https://github.com/nasa/HDTN |
| 鎖定 commit | _(待填)_ |
| 鎖定日期 | _(待填)_ |

## 環境 1：Docker Desktop on macOS

| 項目 | 值 |
|---|---|
| 架構定位 | 多 container 共享 1 個 Linux VM |
| Host | macOS _(版本待填)_ |
| Chip | _(Apple Silicon 型號待填)_ |
| Docker Desktop 版本 | _(待填)_ |
| VM backend | Apple Virtualization Framework / Docker VMM _(待填，於 Docker Desktop 設定中確認)_ |
| Container base image | Ubuntu _(版本待填)_ |
| 配置資源（CPU/Memory） | _(待填)_ |

**注意**：Docker Desktop 的 VM backend 選項在設定中可能有多個（見
`docker/README.md`），務必記錄實際選用的是哪一個，因為不同 backend
效能特性不同。

## 環境 2：Apple `container` CLI

| 項目 | 值 |
|---|---|
| 架構定位 | 每個 container 各自一個 lightweight VM（Virtualization.framework） |
| 需求 | macOS 26+，Apple Silicon |
| Host | macOS _(版本待填)_ |
| `container` CLI 版本 | _(待填，`container --version`)_ |
| Container base image | Ubuntu _(版本待填)_ |

**注意**：截至撰寫時，Apple `container` 官方僅支援 macOS 26+。
若 host 版本不符，這個環境組要整組跳過並在文章中說明，不要硬湊。

## 環境 3：Cloud Linux VM

| 項目 | 值 |
|---|---|
| 架構定位 | Linux VM reference baseline（**不是** native bare-metal） |
| Provider | _(AWS / GCP / 待填)_ |
| Instance type | _(待填)_ |
| vCPU / Memory | _(待填)_ |
| OS image | Ubuntu _(版本待填)_ |
| Region | _(待填，記錄以確認沒有受跨區網路影響本機測試)_ |

## （可選）環境 4：macOS native build

僅在 HDTN 能順利在 Darwin 上 build 時才納入，且明確標註這不是 Linux 對照組，
只用來觀察「完全沒有 Linux VM 介入」時的行為作為額外參考點。

| 項目 | 值 |
|---|---|
| Host | macOS _(版本待填)_ |
| Build 是否成功 | _(待填)_ |
| 遇到的依賴問題 | _(待填，記錄在 limitations.md)_ |

## （未來）環境 5：Raspberry Pi / Bare-metal Linux

留待後續篇章（Raspberry Pi edge node 實測）再展開，目前不在本實驗範圍。
