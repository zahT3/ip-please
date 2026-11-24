#!/bin/bash
# 出口信息源解析：ipinfo 限流时回退 ip-api，两者的字段映射要正确。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$HERE/lib/ip_please.py"
fail=0
pass() { echo "  PASS  $1"; }
nope() { echo "  FAIL  $1"; fail=$((fail+1)); }

echo "ipinfo 限流"
OUT=$(printf '{"status":429,"error":{"title":"Rate limit hit"}}' | python3 "$HELPER" ipjson 2>/dev/null); RC=$?
[ "$RC" -ne 0 ] && [ -z "$OUT" ] && pass "识别 429 并返回失败" || nope "未识别 429（rc=$RC out=$OUT）"

echo "ipinfo 正常"
OUT=$(printf '{"ip":"203.0.113.9","country":"JP","org":"AS17676 SoftBank","hostname":"x.bbtec.net"}' | python3 "$HELPER" ipjson 2>/dev/null)
printf '%s' "$OUT" | grep -q 'JP' && pass "输出国家" || nope "缺国家: $OUT"
printf '%s' "$OUT" | grep -q 'bbtec' && pass "输出反查" || nope "缺反查"

echo "ip-api 回退"
OUT=$(printf '{"status":"success","countryCode":"JP","as":"AS17676 SoftBank Corp.","reverse":"softbank.bbtec.net","hosting":false}' | python3 "$HELPER" ipapi 2>/dev/null); RC=$?
[ "$RC" -eq 0 ] && pass "解析成功" || nope "rc=$RC"
printf '%s' "$OUT" | grep -q 'JP.*AS17676' && pass "国家与 ASN" || nope "字段映射错: $OUT"
printf '%s' "$OUT" | grep -q 'bbtec' && pass "反查" || nope "缺反查: $OUT"
printf '%s' "$OUT" | grep -q '0$' && pass "hosting=0" || nope "hosting 标记错"

OUT=$(printf '{"status":"fail","message":"private range"}' | python3 "$HELPER" ipapi 2>/dev/null); RC=$?
[ "$RC" -ne 0 ] && pass "失败时返回非 0" || nope "失败未识别"

[ "$fail" -eq 0 ] && { echo "全部通过"; exit 0; }
echo "$fail 项失败"; exit 1
