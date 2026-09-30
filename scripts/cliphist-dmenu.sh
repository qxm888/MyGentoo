#!/bin/bash
# 增强剪贴板历史菜单 — Super+G 调用
# 收藏条目独立保存到 ~/Documents/clipboard-favorites/，不受自动清空影响

FAV_DIR="$HOME/Documents/clipboard-favorites"
mkdir -p "$FAV_DIR"

# ===== 生成主菜单 =====
show_main_menu() {
    # 1. 收藏夹管理入口（置顶，确保可见）
    local fav_count=$(ls -1 "$FAV_DIR" 2>/dev/null | wc -l)
    printf '📌 收藏夹管理（共 %d 条收藏）\n' "$fav_count"

    # 2. 收藏条目（⭐ 前缀）
    for f in "$FAV_DIR"/*; do
        [ -f "$f" ] || continue
        local name=$(basename "$f")
        local preview=$(head -1 "$f" 2>/dev/null | tr '\n' ' ' | cut -c1-80)
        printf '⭐ [%s] %s\n' "$name" "$preview"
    done

    # 3. 分隔
    echo "───────────────"

    # 4. cliphist 条目
    cliphist list | while IFS=$'\t' read -r ID PREVIEW; do
        printf '[%s] %s\n' "$ID" "$PREVIEW"
    done
}

# ===== 收藏夹管理子菜单 =====
manage_favorites() {
    local opt
    opt=$(printf '⭐ 加入收藏\n🗑️ 移除收藏\n← 返回' | fuzzel --dmenu --prompt='收藏夹管理' -l 3)
    [ -z "$opt" ] && return

    case "$opt" in
        '⭐ 加入收藏')
            local sel id
            sel=$(cliphist list | while IFS=$'\t' read -r id preview; do
                printf '[%s] %s\n' "$id" "$preview"
            done | fuzzel --dmenu --prompt='选择要收藏的条目' -l 15)
            [ -z "$sel" ] && return

            id=$(echo "$sel" | sed -n 's/^\[\([0-9]*\)\].*/\1/p')
            if [ -n "$id" ]; then
                local filename="$(date +%Y%m%d_%H%M%S)"
                cliphist decode "$id" > "$FAV_DIR/${filename}.txt"
            fi
            ;;

        '🗑️ 移除收藏')
            local sel name
            sel=$(for f in "$FAV_DIR"/*; do
                [ -f "$f" ] || continue
                name=$(basename "$f")
                local preview=$(head -1 "$f" 2>/dev/null | tr '\n' ' ' | cut -c1-80)
                printf '⭐ [%s] %s\n' "$name" "$preview"
            done | fuzzel --dmenu --prompt='选择要移除的收藏' -l 15)
            [ -z "$sel" ] && return

            name=$(echo "$sel" | sed -n 's/^⭐ \[\([^]]*\)\].*/\1/p')
            [ -n "$name" ] && rm -f "$FAV_DIR/$name"
            ;;
    esac
}

# ===== 主流程 =====
SELECTION=$(show_main_menu | fuzzel --dmenu --prompt='剪贴板历史' -l 20 -w 100)
[ -z "$SELECTION" ] && exit 0

case "$SELECTION" in
    *📌*收藏夹管理*)
        manage_favorites
        ;;

    *)
        # cliphist 条目：格式 "[123] preview"
        if echo "$SELECTION" | grep -q '^\[[0-9]'; then
            ID=$(echo "$SELECTION" | sed -n 's/^\[\([0-9]*\)\].*/\1/p')
            [ -n "$ID" ] && cliphist decode "$ID" | wl-copy

        # 收藏条目：格式 "⭐ [filename.txt] preview"
        elif echo "$SELECTION" | grep -q '^⭐'; then
            FILENAME=$(echo "$SELECTION" | sed -n 's/^⭐ \[\([^]]*\)\].*/\1/p')
            [ -n "$FILENAME" ] && [ -f "$FAV_DIR/$FILENAME" ] && cat "$FAV_DIR/$FILENAME" | wl-copy
        fi
        ;;
esac
