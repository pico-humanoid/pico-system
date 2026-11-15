#!/usr/bin/env bash
# 手动输入北京时间，临时恢复系统时间；联网后由 systemd-timesyncd 精确校时。
set -euo pipefail

usage() {
  cat <<'EOF'
用法：
  ./fix-time.sh                         # 交互输入北京时间
  ./fix-time.sh "2026-11-14 20:00:00"   # 日期时间必须作为一个参数
  ./fix-time.sh --help

输入格式：YYYY-MM-DD HH:MM:SS，按北京时间（Asia/Shanghai）解释。
不需要互联网；需要 sudo 权限。手动校时后，按任意键开启并重试网络校时，Ctrl+C 退出。
EOF
}

if [[ ${1:-} == "--help" || ${1:-} == "-h" ]]; then
  usage
  exit 0
fi
if (( $# > 1 )); then
  usage >&2
  exit 2
fi

if (( $# == 1 )); then
  input=$1
else
  printf '当前北京时间：'
  TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S'
  if ! read -r -p '请输入正确的北京时间（YYYY-MM-DD HH:MM:SS）：' input; then
    echo '未读取到时间，已取消。' >&2
    exit 2
  fi
fi

if [[ ! $input =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
  echo '格式错误，示例：2026-11-14 20:00:00' >&2
  exit 2
fi
if ! epoch=$(TZ=Asia/Shanghai date --date="$input" +%s 2>/dev/null); then
  echo '日期或时间无效，未修改系统时间。' >&2
  exit 2
fi
normalized=$(TZ=Asia/Shanghai date --date="@$epoch" '+%Y-%m-%d %H:%M:%S')
if [[ $normalized != "$input" ]]; then
  echo '日期或时间无效，未修改系统时间。' >&2
  exit 2
fi
year=${input:0:4}
if (( 10#$year < 2020 || 10#$year > 2099 )); then
  echo '请输入 2020—2099 年之间的当前时间，未修改系统时间。' >&2
  exit 2
fi

sudo -v
sudo date --set="@$epoch" >/dev/null
printf '手动校时完成（北京时间）：'
TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S'

echo '即将开启并重试自动校时。按任意键继续，Ctrl+C 退出。'
if ! IFS= read -r -s -n 1; then
  echo
  echo '未读取到按键，已退出；手动校时结果保留。'
  exit 0
fi
echo

if ! sudo timedatectl set-ntp true; then
  echo '手动校时已完成，但开启自动校时失败，请检查 timedatectl status。' >&2
  exit 1
fi
if ! sudo systemctl restart systemd-timesyncd.service; then
  echo '手动校时已完成，但重新发起网络校时失败。' >&2
  exit 1
fi

echo '自动校时已开启。请连接网络；时间服务器可达后将自动同步。'
echo '验证：timedatectl show -p NTP -p NTPSynchronized'
echo '只有 NTPSynchronized=yes 才表示已完成网络同步。'
