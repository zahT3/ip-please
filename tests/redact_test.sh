#!/bin/bash
# --redact 的脱敏回归：真实值必须消失，示例值必须出现。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

SAMPLE='  IP                     198.51.100.77
  ASN                    AS64511 Example Upstream
  reverse DNS            77-100-51-198.dynamic.example.net
  配置                   /Users/<user>/Library/Application Support/com.follow.clash/profiles/1234567890123.yaml
  时区                   Asia/Taipei
  地区                   en_US@rg=sgzzzz
  语言                   ( "en-US", "zh-Hans-SG", "en-SG" )
  出口 geo               TW  [PASS]
  出口国家               TW  [PASS]
  claude.ai              198.18.0.23 (fake-ip)'

OUT=$(printf '%s\n' "$SAMPLE" | ( . "$HERE/lib/redact.sh"; redact_stream ))
fail=0
for bad in '198.51.100.77' 'AS3462' 'hinet.net' '3th1z' '1234567890123' 'Taipei' 'zh-Hans-SG' 'com.follow.clash'; do
  if printf '%s' "$OUT" | grep -q "$bad"; then printf '  FAIL  仍含敏感值: %s\n' "$bad"; fail=$((fail+1)); fi
done
for good in '203.0.113.42' 'AS64500 Example Telecom' 'example.net' '<client>' '<profile>' 'Europe/Amsterdam' 'en_NL' 'nl-NL' 'NL'; do
  if ! printf '%s' "$OUT" | grep -q -- "$good"; then printf '  FAIL  缺少脱敏值: %s\n' "$good"; fail=$((fail+1)); fi
done
printf '%s' "$OUT" | grep -q '198.18.0.23' && echo '  PASS  fake-ip 保持原样' || { echo '  FAIL  fake-ip 被误改'; fail=$((fail+1)); }

# 策略组名在数据层脱敏
cat > "$TMP/p.yaml" <<'EOF'
rules:
  - "DOMAIN-SUFFIX,claude.ai,🧲 海外AI"
  - MATCH,DIRECT
EOF
G=$(IP_PLEASE_REDACT=1 python3 "$HERE/lib/ip_please.py" rules "$TMP/p.yaml" claude.ai | awk -F'\t' '/^claude.ai/{print $2}')
[ "$G" = "AI-policy" ] && echo '  PASS  组名脱敏为 AI-policy' || { echo "  FAIL  组名未脱敏: $G"; fail=$((fail+1)); }

[ "$fail" -eq 0 ] && { echo "全部通过"; exit 0; }
echo "$fail 项失败"; exit 1
