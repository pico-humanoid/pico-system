#!/usr/bin/env bash
# acc-vscode-ssh.sh — 加速 VSCode Remote-SSH 首次连接
#
# 症状：VSCode 卡在“正在下载 VS Code 服务器”，几十分钟不动。
# 原因：微软 CDN 对单条连接限速（~50 kB/s），而 VSCode 只用一条连接。
# 做法：识别客户端需要的版本，用 16 条连接并行下载 CLI 和 server，
#       装到正确位置，之后连接时 VSCode 直接命中缓存，不再下载。
#
# 用法：
#   ./acc-vscode-ssh.sh            # 自动识别并补齐缺的部分
#   ./acc-vscode-ssh.sh --check    # 只显示检测结果，不下载
#
# 装完后回到 VSCode：Ctrl+Shift+P -> Reload Window（窗口不关，未保存文件保留）

set -uo pipefail

# 线程数：默认 16，可用 THREADS=24 ./acc-vscode-ssh.sh 临时调大（上限 64）
THREADS="${THREADS:-16}"
case "$THREADS" in ''|*[!0-9]*) THREADS=16 ;; esac
[ "$THREADS" -ge 1 ] && [ "$THREADS" -le 64 ] || THREADS=16
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

say() { printf '%s\n' "$*"; }
die() { printf '\n✗ %s\n' "$*" >&2; exit 1; }

case "$(uname -m)" in
  aarch64|arm64) ARCH=arm64 ;;
  x86_64|amd64)  ARCH=x64 ;;
  armv7l|armhf)  ARCH=armhf ;;
  *) die "不支持的架构: $(uname -m)" ;;
esac

VSD="$HOME/.vscode-server"
mkdir -p "$VSD"

# ---------- 并行下载 + 实时进度 ----------
PIDS=()
TMPD=""
cleanup() {
  printf "\n"
  for p in "${PIDS[@]:-}"; do pkill -P "$p" 2>/dev/null; kill "$p" 2>/dev/null; done
  [ -n "$TMPD" ] && rm -rf "$TMPD"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# fetch_parallel <url> <输出文件> <名称>
fetch_parallel() {
  local url="$1" out="$2" label="$3"
  local size per i s e part have want cur now el alive p total

  size=$(curl -sL -r 0-0 -D - -o /dev/null --max-time 15 "$url" 2>/dev/null \
         | tr -d '\r' | awk 'tolower($1)=="content-range:"{split($3,a,"/"); print a[2]}')
  case "$size" in ''|*[!0-9]*) die "拿不到 $label 的大小，网络可能不通" ;; esac
  [ "$size" -gt 100000 ] || die "$label 大小异常: $size"
  say "  $label：$((size/1024/1024)) MB，$THREADS 条连接并行"

  TMPD=$(mktemp -d)
  PIDS=()
  per=$(( (size + THREADS - 1) / THREADS ))
  for ((i=0; i<THREADS; i++)); do
    s=$((i*per)); e=$((s+per-1)); [ "$e" -ge "$size" ] && e=$((size-1))
    part="$TMPD/p$(printf '%03d' $i)"
    (
      for try in $(seq 1 80); do
        have=$(stat -c %s "$part" 2>/dev/null || echo 0)
        want=$((e-s+1))
        [ "$have" -ge "$want" ] && exit 0
        curl -sL --max-time 300 --speed-limit 2048 --speed-time 20 \
             -r "$((s+have))-$e" "$url" >> "$part" 2>/dev/null
        sz=$(stat -c %s "$part" 2>/dev/null || echo 0)
        [ "$sz" -gt "$want" ] && truncate -s "$want" "$part"
      done
    ) &
    PIDS+=($!)
  done

  local t0=$(date +%s)
  while :; do
    cur=$(du -cb "$TMPD"/p* 2>/dev/null | tail -1 | cut -f1); cur=${cur:-0}
    now=$(date +%s); el=$(( now - t0 )); [ "$el" -lt 1 ] && el=1
    awk -v c="$cur" -v t="$size" -v e="$el" 'BEGIN{
      pct = t>0 ? c*100/t : 0; if (pct > 100) pct = 100;
      rate = c/1024/e;
      eta = (rate>1) ? (t-c)/1024/rate : 0; if (eta < 0) eta = 0;
      if (eta > 3600) es = sprintf("%dh%02dm", int(eta/3600), int((eta%3600)/60));
      else es = sprintf("%dm%02ds", int(eta/60), int(eta%60));
      printf "\r  进度 %5.1f%%   %6.1f / %6.1f MB   %6.0f kB/s   剩余 %-7s", pct, c/1048576, t/1048576, rate, es;
    }'
    alive=0
    for p in "${PIDS[@]}"; do kill -0 "$p" 2>/dev/null && { alive=1; break; }; done
    [ "$alive" = 0 ] && break
    sleep 1
  done
  printf "\r%*s\r" 90 ""

  for p in "${PIDS[@]}"; do wait "$p" 2>/dev/null; done
  cat "$TMPD"/p* > "$out" 2>/dev/null
  total=$(stat -c %s "$out" 2>/dev/null || echo 0)
  [ "$total" = "$size" ] || die "$label 下载不完整（$total / $size 字节），可重新运行本脚本"
  rm -rf "$TMPD"; TMPD=""
  say "  校验通过"
}

# ---------- 1. 识别客户端需要的版本 ----------
COMMIT=""; SRC=""

d=$(ls -dt "$VSD"/cli/servers/Stable-*.staging-* 2>/dev/null | head -1)
if [ -n "$d" ]; then
  COMMIT=$(basename "$d" | sed -n 's/^Stable-\([0-9a-f]\{40\}\)\.staging-.*/\1/p')
  [ -n "$COMMIT" ] && SRC="正在进行的下载"
fi
if [ -z "$COMMIT" ]; then
  COMMIT=$(ps -eo args 2>/dev/null | grep -o 'commit:[0-9a-f]\{40\}' | head -1 | cut -d: -f2)
  [ -n "$COMMIT" ] && SRC="正在运行的下载命令"
fi
if [ -z "$COMMIT" ]; then
  COMMIT=$(cat "$VSD"/.cli.*.log 2>/dev/null | grep -o 'Stable-[0-9a-f]\{40\}' | tail -1 | cut -d- -f2)
  [ -n "$COMMIT" ] && SRC="CLI 日志"
fi
if [ -z "$COMMIT" ]; then
  f=$(ls -t "$VSD"/code-[0-9a-f]* 2>/dev/null | head -1)
  if [ -n "$f" ]; then
    COMMIT=$(basename "$f" | sed -n 's/^code-\([0-9a-f]\{40\}\).*/\1/p')
    [ -n "$COMMIT" ] && SRC="已下载的 CLI 版本"
  fi
fi
if [ -z "$COMMIT" ]; then
  COMMIT=$(curl -fsSL --max-time 8 https://update.code.visualstudio.com/api/releases/stable 2>/dev/null \
           | tr -d '[]", ' | cut -c1-40)
  [ -n "$COMMIT" ] && SRC="官方接口最新版"
fi
[ -n "$COMMIT" ] && [ "${#COMMIT}" -eq 40 ] \
  || die "没识别出需要哪个版本。请先在 VSCode 里连接一次（让它开始下载），再运行本脚本。"

say "加速 VSCode Remote-SSH 首次连接"
say "--------------------------------"
say "架构   : $ARCH"
say "版本   : ${COMMIT:0:8}…（来源：$SRC）"

# ---------- 2. 检查缺什么 ----------
CLI_BIN="$VSD/code-$COMMIT"
DEST_SRV="$VSD/cli/servers/Stable-$COMMIT"
DEST_OLD="$VSD/bin/$COMMIT"

need_cli=0;   [ -x "$CLI_BIN" ] || need_cli=1
need_srv=0;   [ -x "$DEST_SRV/server/bin/code-server" ] || [ -x "$DEST_OLD/bin/code-server" ] || need_srv=1

say "CLI    : $([ "$need_cli" = 1 ] && echo 缺失 || echo 已存在)"
say "server : $([ "$need_srv" = 1 ] && echo 缺失 || echo 已存在)"

if [ "$need_cli" = 0 ] && [ "$need_srv" = 0 ]; then
  say ""
  say "都齐了，不需要下载。"
  say "回到 VSCode：Ctrl+Shift+P -> Reload Window 即可。"
  exit 0
fi

if [ "$CHECK" = 1 ]; then
  say ""
  say "（--check 模式，不下载）"
  exit 0
fi
say ""

# ---------- 3. 下载 CLI ----------
if [ "$need_cli" = 1 ]; then
  say "下载 CLI："
  T=$(mktemp -d)
  fetch_parallel "https://update.code.visualstudio.com/commit:$COMMIT/cli-alpine-$ARCH/stable" "$T/cli.tar.gz" "CLI 包"
  tar -xzf "$T/cli.tar.gz" -C "$T" 2>/dev/null || die "CLI 包解压失败"
  bin=$(find "$T" -maxdepth 2 -type f -name 'code*' | head -1)
  [ -n "$bin" ] || die "CLI 包里找不到可执行文件"
  if [ "$(basename "$bin")" != "code-$COMMIT" ]; then
    cp -f "$bin" "$CLI_BIN"
  fi
  chmod +x "$CLI_BIN"
  rm -rf "$T"
  say "  已安装到 $CLI_BIN"
fi

# ---------- 4. 下载 server ----------
if [ "$need_srv" = 1 ]; then
  say "下载 server："
  T=$(mktemp -d)
  fetch_parallel "https://update.code.visualstudio.com/commit:$COMMIT/server-linux-$ARCH/stable" "$T/srv.tar.gz" "server 包"
  gzip -t "$T/srv.tar.gz" 2>/dev/null || die "server 包校验失败，可重新运行本脚本"
  mkdir -p "$T/x"
  tar -xzf "$T/srv.tar.gz" -C "$T/x" 2>/dev/null || die "server 包解压失败"
  src=$(find "$T/x" -maxdepth 1 -mindepth 1 -type d | head -1)
  [ -n "$src" ] || die "解压后找不到目录"
  mkdir -p "$DEST_SRV/server" "$DEST_OLD"
  cp -a "$src"/. "$DEST_SRV/server"/
  cp -a "$src"/. "$DEST_OLD"/
  chmod +x "$DEST_SRV/server/bin/"* "$DEST_OLD/bin/"* 2>/dev/null
  rm -rf "$T"
  # 清掉残留的 staging，避免 VSCode 以为还在下载
  for d in "$VSD"/cli/servers/Stable-"$COMMIT".staging-*; do [ -d "$d" ] && rm -rf "$d"; done
  say "  已安装到 $DEST_SRV"
fi

say ""
say "完成。现在回到 VSCode："
say "  Ctrl+Shift+P -> Reload Window"
say "（窗口不会关闭，未保存的文件也会保留）"
