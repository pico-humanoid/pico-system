#!/usr/bin/env bash
# fix-nomachine.sh — 重启显示管理器和 NoMachine 服务，修复远程桌面连不上
#
# 用法：
#   ./fix-nomachine.sh        # 交互确认
#   ./fix-nomachine.sh -y     # 跳过确认
#
# 注意：会重启显示管理器，本机图形界面闪断，正在使用的 NoMachine 会话会断开。
set -euo pipefail

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; }

YES=0
case "${1:-}" in
  -y|--yes) YES=1 ;;
  -h|--help) usage; exit 0 ;;
  '') ;;
  *) echo "未知参数：$1" >&2; usage >&2; exit 2 ;;
esac

# NoMachine 服务程序：优先 PATH，其次官方默认位置
if command -v nxserver >/dev/null 2>&1; then
  NXSRV=$(command -v nxserver)
elif [ -x /etc/NX/nxserver ]; then
  NXSRV=/etc/NX/nxserver
else
  echo "未找到 nxserver，本机可能没有安装 NoMachine。" >&2
  exit 1
fi

if [ "$YES" -eq 0 ]; then
  if [ ! -t 0 ]; then
    echo "非交互环境下请加 -y 参数。" >&2
    exit 2
  fi
  cat <<EOF
即将执行：
  1) 重启显示管理器（图形界面会闪断，正在使用的 NoMachine 会话会断开）
  2) 重启 NoMachine 服务：$NXSRV
EOF
  printf '继续？[y/N] '
  read -r ans
  case "$ans" in
    y|Y|yes|YES) ;;
    *) echo "已取消。"; exit 0 ;;
  esac
fi

sudo -v || { echo "需要 sudo 权限。" >&2; exit 1; }

if systemctl cat display-manager.service >/dev/null 2>&1; then
  sudo systemctl stop display-manager || echo "警告：停止显示管理器失败，继续。" >&2
else
  echo "未找到 display-manager.service，跳过这一步。" >&2
fi

sudo "$NXSRV" --restart

echo "修复完成，请重新连接 NoMachine。"
