# Docker Desktop on macOS

架構定位：多個 container 共享 1 個 Linux VM（見 [`../docs/limitations.md`](../docs/limitations.md)）。

## 前置確認

跑之前先確認並填入 `../docs/environment-matrix.md`：

```bash
docker --version
docker info | grep -i "operating system\|cpus\|total memory"
```

並在 Docker Desktop 設定（Settings → General）確認目前使用的 VM backend
（Apple Virtualization Framework / Docker VMM 等），這會影響效能特性，
務必記錄。

## 檔案

| 檔案 | 用途 | 狀態 |
|---|---|---|
| `Dockerfile.hdtn` | build HDTN 的 image | 骨架，待補 build 步驟 |
| `compose.single.yml` | bpgen/hdtn/bpsink 同一個 container 內（topology: single） | 骨架 |
| `compose.multi.yml` | bpgen/hdtn/bpsink 分別獨立 container（topology: multi-container） | 骨架 |

## 執行步驟（待補完）

```bash
# 1. build image（鎖定 docs/environment-matrix.md 中記錄的 HDTN commit）
docker build -f Dockerfile.hdtn -t hdtn-lab:latest ../

# 2. single topology baseline
docker compose -f compose.single.yml up

# 3. multi-container topology
docker compose -f compose.multi.yml up

# 4. 套用延遲（需要先確認 container 內的網路介面名稱）
docker exec -it <container_name> ../scripts/setup_tc_delay.sh eth0 1300
```

## 已知待確認事項

- [ ] Docker container 內預設可能沒有 `iproute2`（`tc` 指令來源），
      需要在 Dockerfile 裡加裝
- [ ] container 內跑 `tc` 通常需要 `--cap-add=NET_ADMIN`，記得加在
      compose 檔或 `docker run` 參數裡
- [ ] multi-container topology 下，container 間的網路介面名稱可能
      不是 `eth0`，需要用 `docker network inspect` 確認
