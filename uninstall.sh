#!/bin/bash
# ip-please 卸载。先豁免再删文件，最后清锚点注册。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/config.example.sh"
[ -f "$HERE/config.sh" ] && . "$HERE/config.sh"
say() { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
ok()  { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }

sudo -v || { printf '需要管理员权限\n' >&2; exit 1; }

say "停用断网保险"
touch "$HOME/.ip-please-pause" "/tmp/.ip-please-pause" 2>/dev/null || touch "$HOME/.ip-please-pause"
. "$HERE/lib/install_guard.sh"
remove_guard || { printf '  卸装失败\n' >&2; exit 1; }
ok "保险已移除"

say "移除浏览器策略"
BROWSER_BUNDLE_IDS="${BROWSER_BUNDLE_IDS:-com.google.Chrome com.brave.Browser}" \
  bash "$HERE/lib/browser-policies.sh" remove >/dev/null 2>&1 || true

say "移除 Claude Code 代理变量"
python3 "$HERE/lib/claude_env.py" remove >/dev/null 2>&1 || true

say "清理状态文件"
sudo rm -rf /etc/ip-please /var/run/ip-please-guard.* /var/log/ip-please-guard.err
rm -f "$HOME/.ip-please-pause" "$HOME/.local/bin/ip-please"

ok "卸载完成"
printf '恢复 IPv6: networksetup -setv6automatic Wi-Fi\n'
