# bpgen config

TODO: 依實際 HDTN 版本，bpgen-async 的參數多數透過 command line flag
傳入（而非獨立 config 檔），實測後把常用參數組合記錄在這裡，
例如：

```bash
bpgen-async \
  --bundle-rate=0 \
  --bundle-size-bytes=<payload_size> \
  --duration=<duration_sec> \
  --my-uri-eid=ipn:10.1 \
  --dest-uri-eid=ipn:20.1
```

實際 flag 名稱請對照鎖定 commit 當下的 `--help` 輸出確認。
