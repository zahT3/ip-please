#!/bin/bash
# Claude Code 配置注入：代理变量 + 遥测关闭（可 opt-out）
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
pass() { echo "  PASS  $1"; }
nope() { echo "  FAIL  $1"; fail=$((fail+1)); }

HOME="$TMP" python3 "$HERE/lib/claude_env.py" install 7890 >/dev/null
S="$TMP/.claude/settings.json"
python3 - "$S" <<'PY' && pass "写入代理与遥测关闭" || nope "写入内容缺失"
import json,sys
e=json.load(open(sys.argv[1]))["env"]
assert e["ALL_PROXY"] == "socks5h://127.0.0.1:7890"
assert e["DISABLE_TELEMETRY"] == "1"
assert e["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] == "1"
PY

TMP2="$(mktemp -d)"
HOME="$TMP2" IP_PLEASE_KEEP_TELEMETRY=1 python3 "$HERE/lib/claude_env.py" install 7890 >/dev/null
S2="$TMP2/.claude/settings.json"
python3 - "$S2" <<'PY' && pass "KEEP_TELEMETRY=1 时不写遥测项" || nope "遥测项未被跳过"
import json,sys
e=json.load(open(sys.argv[1]))["env"]
assert "DISABLE_TELEMETRY" not in e
assert "HTTP_PROXY" in e
PY
rm -rf "$TMP2"

HOME="$TMP" python3 "$HERE/lib/claude_env.py" remove >/dev/null
python3 - "$S" <<'PY' && pass "remove 只清代理变量" || nope "remove 行为不对"
import json,sys
e=json.load(open(sys.argv[1]))["env"]
assert "HTTP_PROXY" not in e
assert e.get("DISABLE_TELEMETRY") == "1"
PY

[ "$fail" -eq 0 ] && { echo "全部通过"; exit 0; }
echo "$fail 项失败"; exit 1
