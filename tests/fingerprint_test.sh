#!/bin/bash
# 环境一致性判定：不一致必须计入失败，未知国家只提示。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP"
CACHE="$TMP/ip-please-exit-$(id -u).cache"
fail=0

printf 'JP\tExample Telecom\texample.jp\t0\t203.0.113.42\n' > "$CACHE"
OUT=$("$HERE/bin/ip-please" --plain fingerprint 2>&1); RC=$?
[ "$RC" -ne 0 ] && echo '  PASS  时区不一致时退出码非 0' || { echo "  FAIL  退出码=$RC"; fail=$((fail+1)); }
printf '%s' "$OUT" | grep -q '≠' && echo '  PASS  输出包含期望时区' || { echo '  FAIL  缺少期望时区提示'; fail=$((fail+1)); }

printf 'ZZ\tExample Telecom\texample.zz\t0\t203.0.113.42\n' > "$CACHE"
OUT=$("$HERE/bin/ip-please" --plain fingerprint 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo '  PASS  未知国家不计失败' || { echo "  FAIL  未知国家退出码=$RC"; fail=$((fail+1)); }
printf '%s' "$OUT" | grep -q '无对应规则' && echo '  PASS  未知国家给出提示' || { echo '  FAIL  未知国家无提示'; fail=$((fail+1)); }

[ "$fail" -eq 0 ] && { echo "全部通过"; exit 0; }
echo "$fail 项失败"; exit 1
