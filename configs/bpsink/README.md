# bpsink config

TODO: 同 bpgen，多數參數透過 command line flag 傳入，實測後記錄
常用組合：

```bash
bpsink-async \
  --my-uri-eid=ipn:20.1 \
  --save-directory=<output_dir>
```

實際 flag 名稱請對照鎖定 commit 當下的 `--help` 輸出確認。
goodput 的計算方式（bpsink 是否會印出 received bytes/duration）
也需要實測後記錄在 `scripts/parse_results.py` 的 `parse_hdtn_log`
函式裡。
