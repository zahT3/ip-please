#!/bin/bash
# 回归：pipefail 下，RELAUNCH_APP 为空时生成 guard.conf 不能失败（曾导致安装中止）
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/lib/install_guard.sh"
fail=0

run() { # run <desc> <relaunch> <expect-lines>
  local out rc n
  out=$(bash -c 'set -euo pipefail; . "$1"; _guard_conf "ip-please-guard" 7890 "$2" | cat' _ "$HERE/lib/install_guard.sh" "$2")
  rc=$?
  n=$(printf '%s\n' "$out" | grep -c '^GUARD_')
  if [ "$rc" -eq 0 ]; then printf '  PASS  %s（rc=0）\n' "$1"; else printf '  FAIL  %s（rc=%s）\n' "$1" "$rc"; fail=$((fail+1)); fi
  if [ "$n" -eq "$3" ]; then printf '  PASS  %s（%s 行）\n' "$1" "$n"; else printf '  FAIL  %s（行数 %s，期望 %s）\n' "$1" "$n" "$3"; fail=$((fail+1)); fi
}

echo "guard.conf 生成"
run "RELAUNCH_APP 为空" "" 2
run "RELAUNCH_APP 非空" "FlClash" 3

[ "$fail" -eq 0 ] && { echo "全部通过"; exit 0; }
echo "$fail 项失败"; exit 1
