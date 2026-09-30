#!/bin/bash
# auto-snapshot.sh  (Gentoo 侧)

SNAPSHOT_DIR="/.snapshots"
#SNAPSHOT_DIRH="/.homesnapshots"
DATE=$(date +%Y%m%d-%H%M%S)
TODAY=$(date +%Y%m%d)

# 创建根快照（Gentoo 用 gentoo- 前缀，Arch 用 root- 前缀，两边互不干扰）
sudo btrfs subvolume snapshot -r / "$SNAPSHOT_DIR/gentoo-$DATE"

# 创建 home 快照（如果单独子卷）
# 注意：@home 现在是 Gentoo/Arch 共用子卷，Arch 有每周 timer 也会快照 /home，
#       所以当天已有 home- 快照就跳过，避免双系统重复。
if [ -d "/home" ]; then
    if ls -d "$SNAPSHOT_DIR"/home-$TODAY-* >/dev/null 2>&1; then
        echo "当天已有 home 快照，跳过"
    else
        sudo btrfs subvolume snapshot -r /home "$SNAPSHOT_DIR/home-$DATE"
    fi
fi

# 保留最近7个快照（各前缀独立计数）
# 修复：原来这里写的是 root-*，但本脚本创建的是 gentoo-*，
#       会导致 Gentoo 一跑就删掉 Arch 的 root-* 快照。
find "$SNAPSHOT_DIR" -maxdepth 1 -name "gentoo-*" -type d | sort -r | tail -n +8 | xargs -r sudo btrfs subvolume delete
find "$SNAPSHOT_DIR" -maxdepth 1 -name "home-*"   -type d | sort -r | tail -n +8 | xargs -r sudo btrfs subvolume delete
