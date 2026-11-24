#!/bin/bash
# 环境一致性判定：时区不一致 / 地区不一致 / 未知国家 / 严格模式。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP"
CACHE="$TMP/ip-please-exit-$(id -u).cache"
BIN="$HERE/bin/ip-please"
fail=0
pass() { echo "  PASS  $1"; }
nope() { echo "  FAIL  $1"; fail=$((fail+1)); }

set_cache() { printf '%s\tExample Telecom\texample.net\t0\t203.0.113.42\n' "$1" > "$CACHE"; }

echo "时区不一致"
set_cache JP
OUT=$(IP_PLEASE_LOCALE_OVERRIDE='en_US' IP_PLEASE_TZ_OVERRIDE='Asia/Taipei' "$BIN" --plain fingerprint 2>&1); RC=$?
[ "$RC" -ne 0 ] && pass "退出码非 0" || nope "退出码=$RC"
printf '%s' "$OUT" | grep -q '≠' && pass "给出期望时区" || nope "缺少期望时区"

echo "地区覆盖不一致（en + SG vs TW）"
set_cache TW
OUT=$(IP_PLEASE_LOCALE_OVERRIDE='en_US@rg=sgzzzz' IP_PLEASE_TZ_OVERRIDE='Asia/Taipei' "$BIN" --plain fingerprint 2>&1); RC=$?
[ "$RC" -eq 0 ] && pass "非严格模式只警告" || nope "非严格模式退出码=$RC"
printf '%s' "$OUT" | grep -q '区域覆盖=SG' && pass "解码出区域覆盖 SG" || nope "未解码区域覆盖"
printf '%s' "$OUT" | grep -q '区域=SG ≠ 出口 TW' && pass "指出区域与出口不一致" || nope "未指出不一致"

echo "严格模式"
OUT=$(FINGERPRINT_STRICT=1 IP_PLEASE_LOCALE_OVERRIDE='en_US@rg=sgzzzz' IP_PLEASE_TZ_OVERRIDE='Asia/Taipei' "$BIN" --plain fingerprint 2>&1); RC=$?
[ "$RC" -ne 0 ] && pass "严格模式判失败" || nope "严格模式退出码=$RC"

echo "CJK 语言 + 非对应地区"
set_cache US
OUT=$(IP_PLEASE_LOCALE_OVERRIDE='zh_CN' IP_PLEASE_TZ_OVERRIDE='America/New_York' "$BIN" --plain fingerprint 2>&1); RC=$?
[ "$RC" -ne 0 ] && pass "判失败" || nope "退出码=$RC"
printf '%s' "$OUT" | grep -q '语言 zh' && pass "提示语言 zh" || nope "缺少语言提示"

echo "完全对齐"
OUT=$(IP_PLEASE_LOCALE_OVERRIDE='en_US' IP_PLEASE_TZ_OVERRIDE='America/New_York' "$BIN" --plain fingerprint 2>&1); RC=$?
[ "$RC" -eq 0 ] && pass "退出码 0" || nope "退出码=$RC"

echo "未知国家"
set_cache ZZ
OUT=$(IP_PLEASE_LOCALE_OVERRIDE='en_US' IP_PLEASE_TZ_OVERRIDE='Asia/Taipei' "$BIN" --plain fingerprint 2>&1); RC=$?
[ "$RC" -eq 0 ] && pass "不计失败" || nope "退出码=$RC"
printf '%s' "$OUT" | grep -q '无对应规则' && pass "给出提示" || nope "缺少提示"

[ "$fail" -eq 0 ] && { echo "全部通过"; exit 0; }
echo "$fail 项失败"; exit 1
