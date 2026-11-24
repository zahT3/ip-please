#!/bin/bash
# 规则解析与 --fix 的回归测试。用固定样本，不碰真实订阅。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$HERE/lib/ip_please.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PROFILE="$TMP/profile.yaml"
cat > "$PROFILE" <<'EOF'
mixed-port: 7890
rules:
  - "DOMAIN-SUFFIX,claude.ai,\U0001F9F2 AI-policy"
  - "DOMAIN-SUFFIX,statsig.com,\U0001F9F2 AI-policy"
  - MATCH,🐟 漏网之鱼
EOF

fail=0
expect_rc() { # expect_rc <desc> <want> <actual>
  if [ "$3" -eq "$2" ]; then printf '  PASS  %s\n' "$1"; else printf '  FAIL  %s (rc=%s want %s)\n' "$1" "$3" "$2"; fail=$((fail+1)); fi
}

echo "rules parser"
out=$(python3 "$HELPER" rules "$PROFILE" claude.ai statsig.com); rc=$?
expect_rc "两个 AI 域名同组" 0 "$rc"
printf '%s\n' "$out" | grep -q '^claude.ai	🧲 AI-policy$' && printf '  PASS  转义 emoji 正确解码\n' || { printf '  FAIL  组名解码错误\n'; fail=$((fail+1)); }

python3 "$HELPER" rules "$PROFILE" claude.ai example.org >/dev/null; rc=$?
expect_rc "存在旁路域名时返回 1" 1 "$rc"

printf 'mixed-port: 1\n' > "$TMP/norules.yaml"
python3 "$HELPER" rules "$TMP/norules.yaml" claude.ai >/dev/null 2>&1; rc=$?
expect_rc "缺少 rules 段返回 2" 2 "$rc"

echo "fix"
n=$(python3 "$HELPER" fix "$PROFILE" "🎯 绕过代理" statsig.com claude.googleapis.com); rc=$?
expect_rc "fix 成功" 0 "$rc"
[ "$n" = "2" ] && printf '  PASS  只插入缺失的 2 条\n' || { printf '  FAIL  插入条数=%s want 2\n' "$n"; fail=$((fail+1)); }
n=$(python3 "$HELPER" fix "$PROFILE" "🎯 绕过代理" statsig.com claude.googleapis.com)
[ "$n" = "0" ] && printf '  PASS  fix 幂等（第二次插入 0 条）\n' || { printf '  FAIL  fix 非幂等，第二次插入 %s 条\n' "$n"; fail=$((fail+1)); }
grep -q 'DOMAIN-SUFFIX,claude.googleapis.com,🎯 绕过代理' "$PROFILE" && printf '  PASS  新规则已写入\n' || { printf '  FAIL  新规则未写入\n'; fail=$((fail+1)); }

python3 "$HELPER" fix "$TMP/norules.yaml" g a.com >/dev/null 2>&1; rc=$?
expect_rc "fix 缺 rules 段时返回 2 而非崩溃" 2 "$rc"

# 策略组名校验：组不存在时拒绝写入，避免把订阅写坏
cat > "$TMP/groups.yaml" <<'EOF'
proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies: [DIRECT]
  - name: "AI"
    type: select
    proxies: [DIRECT]
rules:
  - DOMAIN-SUFFIX,claude.ai,AI
  - MATCH,DIRECT
EOF
err=$(python3 "$HELPER" fix "$TMP/groups.yaml" "不存在的组" claude.ai 2>&1); rc=$?
expect_rc "fix 拒绝不存在的策略组" 3 "$rc"
printf '%s' "$err" | grep -q '🚀 节点选择' && printf '  PASS  错误信息列出可用组\n' || { printf '  FAIL  未列出可用组\n'; fail=$((fail+1)); }
n=$(python3 "$HELPER" fix "$TMP/groups.yaml" "AI" example.com); rc=$?
expect_rc "fix 接受已存在的策略组" 0 "$rc"

[ "$fail" -eq 0 ] && { echo "全部通过"; exit 0; }
echo "$fail 项失败"; exit 1
