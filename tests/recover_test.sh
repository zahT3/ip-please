#!/bin/bash
# ipp recover 的恢复逻辑：残留代理/DNS 是否被清理、健康时不乱动。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home"
LOG="$TMP/calls.log"; : > "$LOG"
HOME_DIR="$TMP/home"

cat > "$TMP/bin/nc" <<'EOF'
#!/bin/bash
[ "${TEST_UP:-0}" = "1" ] && exit 0
exit 1
EOF
cat > "$TMP/bin/ifconfig" <<'EOF'
#!/bin/bash
[ "${TEST_TUN:-0}" = "1" ] && echo "	inet 198.18.0.1 netmask 0xffff0000"
exit 0
EOF
cat > "$TMP/bin/scutil" <<'EOF'
#!/bin/bash
case "$1" in
  --proxy) [ "${TEST_PROXY:-0}" = "1" ] && echo "  HTTPEnable : 1" ;;
  --dns)   [ "${TEST_DNS:-0}" = "1" ] && echo "  nameserver[0] : 198.18.0.2" ;;
esac
exit 0
EOF
cat > "$TMP/bin/networksetup" <<EOF
#!/bin/bash
echo "networksetup \$*" >> "$LOG"
if [ "\$1" = "-listnetworkserviceorder" ]; then
  printf '(1) Wi-Fi\n(Hardware Port: Wi-Fi, Device: en0)\n'
fi
exit 0
EOF
cat > "$TMP/bin/sudo" <<'EOF'
#!/bin/bash
exec "$@"
EOF
cat > "$TMP/bin/pgrep" <<'EOF'
#!/bin/bash
[ "${TEST_BUSY:-0}" = "1" ] && exit 0
exit 1
EOF
cat > "$TMP/bin/lsof" <<'EOF'
#!/bin/bash
exit 0
EOF
for c in dscacheutil killall osascript open route; do
cat > "$TMP/bin/$c" <<EOF
#!/bin/bash
echo "$c \$*" >> "$LOG"
if [ "$c" = "route" ]; then echo "  interface: en0"; fi
exit 0
EOF
done
chmod +x "$TMP/bin/"*

fail=0
pass() { echo "  PASS  $1"; }
nope() { echo "  FAIL  $1"; fail=$((fail+1)); }

run() { # run <TEST_UP> <TEST_TUN> <TEST_PROXY> <TEST_DNS> [--restart]
  : > "$LOG"
  rm -f "$HOME_DIR/.ip-please-pause"
  TEST_UP="$1" TEST_TUN="$2" TEST_PROXY="$3" TEST_DNS="$4" \
  HOME="$HOME_DIR" PATH="$TMP/bin:$PATH" \
  IP_PLEASE_NC="$TMP/bin/nc" IP_PLEASE_IFCONFIG="$TMP/bin/ifconfig" \
  IP_PLEASE_SCUTIL="$TMP/bin/scutil" IP_PLEASE_NETWORKSETUP="$TMP/bin/networksetup" \
  IP_PLEASE_SUDO="$TMP/bin/sudo" IP_PLEASE_DSCACHEUTIL="$TMP/bin/dscacheutil" \
  IP_PLEASE_KILLALL="$TMP/bin/killall" IP_PLEASE_OSASCRIPT="$TMP/bin/osascript" \
  IP_PLEASE_OPEN="$TMP/bin/open" IP_PLEASE_RECOVER_TRIES=1 \
  "$HERE/bin/ip-please" --plain recover ${5:-} >/dev/null 2>&1
  return $?
}

echo "健康状态"
run 1 1 1 0; rc=$?
[ "$rc" -eq 0 ] && pass "健康时返回 0" || nope "健康时 rc=$rc"
grep -q 'setwebproxystate' "$LOG" && nope "健康时不应改系统代理" || pass "健康时未改系统代理"
[ -e "$HOME_DIR/.ip-please-pause" ] && nope "健康时不应创建豁免标记" || pass "健康时未创建豁免标记"

echo "残留恢复"
run 0 0 1 1; rc=$?
[ "$rc" -ne 0 ] && pass "恢复失败时返回非 0" || nope "失败未返回非 0"
grep -q 'setwebproxystate Wi-Fi off' "$LOG" && pass "关闭了系统代理" || nope "未关闭系统代理"
grep -q 'setsecurewebproxystate' "$LOG" && pass "关闭了 HTTPS 代理" || nope "未关闭 HTTPS 代理"
grep -q 'setdnsservers Wi-Fi Empty' "$LOG" && pass "DNS 恢复为 DHCP" || nope "未恢复 DNS"
grep -q 'dscacheutil -flushcache' "$LOG" && pass "刷新 DNS 缓存" || nope "未刷新缓存"
[ -e "$HOME_DIR/.ip-please-pause" ] && pass "失败时保持暂停" || nope "失败时未保持暂停"

echo "带 --restart"
run 0 0 0 0 --restart
grep -q 'quit app "FlClash"' "$LOG" && pass "尝试退出 FlClash" || nope "未退出 FlClash"
grep -q 'open -a FlClash' "$LOG" && pass "重新打开 FlClash" || nope "未打开 FlClash"

echo "Claude 活动时拒绝重启"
: > "$LOG"; rm -f "$HOME_DIR/.ip-please-pause"
TEST_BUSY=1 TEST_UP=0 TEST_TUN=0 HOME="$HOME_DIR" PATH="$TMP/bin:$PATH" \
  IP_PLEASE_NC="$TMP/bin/nc" IP_PLEASE_IFCONFIG="$TMP/bin/ifconfig" \
  IP_PLEASE_SCUTIL="$TMP/bin/scutil" IP_PLEASE_NETWORKSETUP="$TMP/bin/networksetup" \
  IP_PLEASE_SUDO="$TMP/bin/sudo" IP_PLEASE_RECOVER_TRIES=1 \
  "$HERE/bin/ip-please" --plain recover --restart >/dev/null 2>&1
[ $? -ne 0 ] && pass "busy 时返回非 0" || nope "busy 时未拒绝"
grep -q 'quit app "FlClash"' "$LOG" && nope "busy 时仍退出 FlClash" || pass "busy 时未动 FlClash"

[ "$fail" -eq 0 ] && { echo "全部通过"; exit 0; }
echo "$fail 项失败"; exit 1
