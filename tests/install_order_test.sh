#!/bin/bash
# 安装顺序的静态断言：豁免先于一切网络改动，验证通过才武装。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$HERE/install.sh"
fail=0

pass() { printf '  PASS  %s\n' "$1"; }
nope() { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }

echo "install order"
line_of() { grep -n "$1" "$2" | head -1 | cut -d: -f1; }

pa=$(line_of 'touch "\$PAUSE"' "$INSTALL")
ig=$(line_of 'install_guard "\$HERE"' "$INSTALL")
rmp=$(line_of 'rm -f "\$PAUSE"' "$INSTALL")
doc=$(line_of 'doctor --pre' "$INSTALL")

[ -n "$pa" ] && [ -n "$ig" ] && [ "$pa" -lt "$ig" ] && pass "豁免文件先于安装" || nope "豁免文件没有先于安装"
[ -n "$doc" ] && [ -n "$rmp" ] && [ "$doc" -lt "$rmp" ] && pass "验证通过后才移除豁免" || nope "移除豁免早于验证"
grep -q 'set -euo pipefail' "$INSTALL" && pass "启用 set -e（失败即中止）" || nope "缺少 set -e"
grep -q 'trap on_exit EXIT' "$INSTALL" && pass "失败时提示豁免文件仍存在" || nope "缺少失败提示"

echo "no unsudoed pf.conf edits"
for f in "$HERE/bin/ip-please" "$HERE/uninstall.sh" "$HERE/install.sh" "$HERE/lib/install_guard.sh" "$HERE/lib/guard.sh"; do
  if grep -n "sed -i ''" "$f" 2>/dev/null | grep -v 'sudo sed' >/dev/null; then
    nope "$(basename "$f") 存在未加 sudo 的 sed 编辑"
  fi
done
pass "pf.conf 编辑均带 sudo"

[ "$fail" -eq 0 ] && { echo "全部通过"; exit 0; }
echo "$fail 项失败"; exit 1
