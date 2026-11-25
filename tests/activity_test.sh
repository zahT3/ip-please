#!/bin/bash
# ipp activity 的判定：Claude 活动时必须返回非 0，空闲时 0。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home"
cat > "$TMP/bin/pgrep" <<'EOF'
#!/bin/bash
[ "${TEST_DESKTOP:-0}" = "1" ] && exit 0
[ "${TEST_CLI:-0}" = "1" ] && exit 0
exit 1
EOF
cat > "$TMP/bin/lsof" <<'EOF'
#!/bin/bash
[ "${TEST_CONN:-0}" = "1" ] && echo "Claude 1 3th1z 21u IPv4 ... TCP 127.0.0.1:1->127.0.0.1:7890 (ESTABLISHED)"
exit 0
EOF
chmod +x "$TMP/bin/pgrep" "$TMP/bin/lsof"
fail=0
run() { HOME="$TMP/home" PATH="$TMP/bin:$PATH" TEST_DESKTOP="${1:-0}" TEST_CLI="${2:-0}" TEST_CONN="${3:-0}" \
  "$HERE/bin/ip-please" --plain activity >/dev/null 2>&1; return $?; }

echo "活动检测"
run 0 0 0 && echo "  PASS  空闲返回 0" || { echo "  FAIL  空闲返回非 0"; fail=$((fail+1)); }
run 1 0 0; [ $? -ne 0 ] && echo "  PASS  Claude Desktop 运行时返回非 0" || { echo "  FAIL  未检测 Desktop"; fail=$((fail+1)); }
run 0 1 0; [ $? -ne 0 ] && echo "  PASS  Claude CLI 运行时返回非 0" || { echo "  FAIL  未检测 CLI"; fail=$((fail+1)); }
run 0 0 1; [ $? -ne 0 ] && echo "  PASS  有代理连接时返回非 0" || { echo "  FAIL  未检测连接"; fail=$((fail+1)); }

OUT=$(HOME="$TMP/home" PATH="$TMP/bin:$PATH" TEST_DESKTOP=1 "$HERE/bin/ip-please" activity --json 2>/dev/null)
printf '%s' "$OUT" | grep -q '"busy":true' && echo "  PASS  JSON busy=true" || { echo "  FAIL  JSON: $OUT"; fail=$((fail+1)); }

[ "$fail" -eq 0 ] && { echo "全部通过"; exit 0; }
echo "$fail 项失败"; exit 1
