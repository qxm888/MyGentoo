#!/bin/bash
# 剪贴板智能存储 — 满 100 条自动清空最旧条目
# 用法: wl-paste --type text --watch ~/opencode/scripts/cliphist-smart-store.sh

MAX_ITEMS=100

cliphist store

TOTAL=$(cliphist list | wc -l)
if [ "$TOTAL" -gt "$MAX_ITEMS" ]; then
    cliphist list | awk '{print $1}' | head -n -"$MAX_ITEMS" | while read -r ID; do
        [ -n "$ID" ] && cliphist delete "$ID" 2>/dev/null
    done
fi
