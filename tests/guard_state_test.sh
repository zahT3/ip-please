#!/bin/bash
# 断网保险状态机回归测试。用假的 pfctl / nc，不碰真实防火墙。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/run" "$TMP/home"
RULES="$TMP/rules.txt"
: > "$RULES"

cat > "$TMP/bin/pfctl" <<EOF
#!/bin/bash
case "\$*" in
  *"-F rules"*) : > "$RULES" ;;
  *"-sr"*) cat "$RULES" 2>/dev/null ;;
  *"-f -"*) cat >> "$RULES" ;;
  *"-f "*) exit 0 ;;
esac
exit 0
EOF
cat > "$TMP/bin/nc" <<'EOF'
#!/bin/bash
[ "${IP_PLEASE_TEST_UP:-0}" = "1" ] && exit 0
exit 1
EOF
cat > "$TMP/bin/ifconfig" <<'EOF'
#!/bin/bash
[ "${IP_PLEASE_TEST_TUN:-1}" = "1" ] && echo "	inet 198.18.0.1 netmask 0xffff0000"
exit 0
EOF
chmod +x "$TMP/bin/pfctl" "$TMP/bin/nc" "$TMP/bin/ifconfig"

export IP_PLEASE_CONF="$TMP/guard.conf"
export IP_PLEASE_PF_CONF="$TMP/pf.conf"
export IP_PLEASE_PFCTL="$TMP/bin/pfctl"
export IP_PLEASE_NC="$TMP/bin/nc"
export IP_PLEASE_RUN="$TMP/run"
export IP_PLEASE_HOME="$TMP/home"
export IP_PLEASE_IFCONFIG="$TMP/bin/ifconfig"
: > "$IP_PLEASE_CONF"
printf 'anchor "ip-please-guard"\n' > "$IP_PLEASE_PF_CONF"

fail=0
check() { # check <desc> <expected-size> 
  local n
  n=$(grep -c '^block' "$RULES" 2>/dev/null || true)
  if [ "$n" -eq "$2" ]; then printf '  PASS  %s\n' "$1"; else printf '  FAIL  %s (block rules=%s, want %s)\n' "$1" "$n" "$2"; fail=$((fail+1)); fi
}
backdate() { printf '%s\n' $(( $(date +%s) - 1000 )) > "$IP_PLEASE_RUN/ip-please-guard.state"; }

echo "guard state machine"
IP_PLEASE_TEST_UP=1 "$HERE/lib/guard.sh"; check "代理在线时不设规则" 0

rm -f "$IP_PLEASE_RUN/ip-please-guard.state"
IP_PLEASE_TEST_UP=1 "$HERE/lib/guard.sh"
backdate
IP_PLEASE_TEST_UP=0 "$HERE/lib/guard.sh"; check "代理掉线后跳闸" 2

touch "$IP_PLEASE_HOME/.ip-please-pause"
IP_PLEASE_TEST_UP=0 "$HERE/lib/guard.sh"; check "豁免文件使规则清空" 0
rm -f "$IP_PLEASE_HOME/.ip-please-pause"

echo "宽限期"
IP_PLEASE_TEST_UP=1 "$HERE/lib/guard.sh"
printf '%s\n' "$(date +%s)" > "$IP_PLEASE_RUN/ip-please-guard.state"
IP_PLEASE_TEST_UP=0 IP_PLEASE_TEST_TUN=1 "$HERE/lib/guard.sh"; check "TUN 在、刚掉线：宽限期不阻断" 0
IP_PLEASE_TEST_UP=0 IP_PLEASE_TEST_TUN=0 "$HERE/lib/guard.sh"; check "TUN 消失：跳过宽限立即阻断" 2

: > "$RULES"; rm -f "$IP_PLEASE_RUN/ip-please-guard.state"
IP_PLEASE_TEST_UP=1 "$HERE/lib/guard.sh"
backdate
IP_PLEASE_TEST_UP=0 IP_PLEASE_TEST_TUN=1 "$HERE/lib/guard.sh"; check "TUN 在、超宽限：阻断" 2

echo "暂停过期"
: > "$RULES"
printf 'until=%s\n' $(( $(date +%s) - 10 )) > "$IP_PLEASE_HOME/.ip-please-pause"
IP_PLEASE_TEST_UP=1 IP_PLEASE_TEST_TUN=1 "$HERE/lib/guard.sh"
[ -e "$IP_PLEASE_HOME/.ip-please-pause" ] && { echo "  FAIL  过期标记未清除"; fail=$((fail+1)); } || echo "  PASS  过期标记已清除"
printf 'until=%s\n' $(( $(date +%s) + 300 )) > "$IP_PLEASE_HOME/.ip-please-pause"
IP_PLEASE_TEST_UP=0 IP_PLEASE_TEST_TUN=1 "$HERE/lib/guard.sh"; check "未过期暂停不阻断" 0
[ -e "$IP_PLEASE_HOME/.ip-please-pause" ] && echo "  PASS  未过期标记保留" || { echo "  FAIL  未过期标记被删"; fail=$((fail+1)); }
rm -f "$IP_PLEASE_HOME/.ip-please-pause"

printf '%s\n' $(( $(date +%s) - 1000 )) > "$IP_PLEASE_RUN/ip-please-guard.blocked"
backdate
IP_PLEASE_TEST_UP=0 "$HERE/lib/guard.sh"; check "TTL 超时后放开" 0
[ -f "$IP_PLEASE_RUN/ip-please-guard.open" ] && printf '  PASS  TTL 写入冷却窗口\n' || { printf '  FAIL  TTL 未写冷却窗口\n'; fail=$((fail+1)); }

touch "$IP_PLEASE_HOME/.ip-please-pause"
IP_PLEASE_TEST_UP=0 "$HERE/lib/guard.sh"
[ ! -f "$IP_PLEASE_RUN/ip-please-guard.open" ] && printf '  PASS  豁免清除冷却窗口\n' || { printf '  FAIL  豁免未清冷却窗口\n'; fail=$((fail+1)); }
rm -f "$IP_PLEASE_HOME/.ip-please-pause" "$IP_PLEASE_RUN/ip-please-guard.open"

printf 'rules:\n  - MATCH,DIRECT\n' > "$IP_PLEASE_PF_CONF"
backdate
rm -f "$IP_PLEASE_RUN/ip-please-guard.state"
IP_PLEASE_TEST_UP=0 "$HERE/lib/guard.sh" >/dev/null 2>&1
backdate
IP_PLEASE_TEST_UP=0 "$HERE/lib/guard.sh" >/dev/null 2>&1
grep -q 'anchor "ip-please-guard"' "$IP_PLEASE_PF_CONF" && printf '  PASS  锚点缺失时自动补注册\n' || { printf '  FAIL  锚点未补注册\n'; fail=$((fail+1)); }

[ "$fail" -eq 0 ] && { echo "全部通过"; exit 0; }
echo "$fail 项失败"; exit 1
