#!/usr/bin/env bash
# 延时全屏截图 —— 解决弹窗/菜单一类失焦自动关闭截不到的问题
# 用法: hyprshot-delay.sh [秒数]   (默认 3 秒)

set -e

DELAY="${1:-3}"
SAVEDIR="${HOME}/screenshot"

mkdir -p "$SAVEDIR"

notify-send "延时截图" "将在 ${DELAY} 秒后截图，抓紧打开弹窗哦~" -t $((DELAY * 1000)) -a Hyprshot

sleep "$DELAY"

FILENAME="$(date +'%Y-%m-%d-%H%M%S_delay.png')"
FULLPATH="${SAVEDIR}/${FILENAME}"

ACTIVE_WS=$(hyprctl -j activeworkspace)
MONITOR_ID=$(echo "$ACTIVE_WS" | jq -r '.monitorID')
MONITOR=$(hyprctl -j monitors | jq -r ".[] | select(.id == $MONITOR_ID)")
GEOMETRY=$(echo "$MONITOR" | jq -r '"\(.x),\(.y) \(.width/.scale|round)x\(.height/.scale|round)"')

grim -g "$GEOMETRY" "$FULLPATH"
wl-copy --type image/png < "$FULLPATH"
notify-send "截图已保存" "$FULLPATH" -i "$FULLPATH" -t 3000 -a Hyprshot
