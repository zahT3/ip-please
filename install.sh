#!/bin/bash
# ip-please 安装 / 升级 / 迁移。先豁免、再安装、再验证，验证不过不武装。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/config.example.sh"
[ -f "$HERE/config.sh" ] && . "$HERE/config.sh"

PAUSE="$HOME/.ip-please-pause"

say() { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
ok()  { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
wrn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m  ✗ %s\033[0m\n' "$*"; exit 1; }

on_exit() {
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '\n\033[1;33m安装中止。断网保险保持休眠（%s 存在），网络不受影响。\033[0m\n' "$PAUSE"
    printf '修好后重跑：%s/install.sh\n' "$HERE"
  fi
}
trap on_exit EXIT

[[ "$(uname -s)" == "Darwin" ]] || die "仅支持 macOS"
[[ $EUID -ne 0 ]] || die "请用普通用户运行"

say "预检"
sudo -v || die "需要管理员权限"
command -v python3 >/dev/null || die "缺少 python3"
command -v curl >/dev/null || die "缺少 curl"
ok "环境正常"

say "创建豁免文件（安装期间保险休眠）"
touch "$PAUSE"
ok "$PAUSE"

LEGACY_PLISTS="/Library/LaunchDaemons/local.airlock.guard.plist /Library/LaunchDaemons/local.gecko.guard.plist /Library/LaunchDaemons/local.claude.guard.plist"
for old in $LEGACY_PLISTS; do
  [ -f "$old" ] || continue
  say "迁移旧安装: $old"
  sudo launchctl bootout system "$old" >/dev/null 2>&1 || true
  case "$old" in
    *airlock*) sudo rm -f "$old" /usr/local/bin/airlock-guard /etc/pf.anchors/airlock-guard
               sudo rm -rf /etc/airlock
               sudo pfctl -a airlock-guard -F rules >/dev/null 2>&1 || true
               if grep -q 'anchor "airlock-guard"' /etc/pf.conf 2>/dev/null; then
                 sudo sed -i '' '/anchor "airlock-guard"/d' /etc/pf.conf
               fi ;;
    *gecko*) sudo rm -f "$old" /usr/local/bin/gecko-guard /etc/pf.anchors/gecko-guard
             sudo rm -rf /etc/gecko
             sudo pfctl -a gecko-guard -F rules >/dev/null 2>&1 || true
             if grep -q 'anchor "gecko-guard"' /etc/pf.conf 2>/dev/null; then
               sudo sed -i '' '/anchor "gecko-guard"/d' /etc/pf.conf
             fi ;;
    *)       sudo rm -f "$old" /usr/local/bin/claude-guard.sh /etc/pf.anchors/claude-guard
             sudo pfctl -a claude-guard -F rules >/dev/null 2>&1 || true
             if grep -q 'anchor "claude-guard"' /etc/pf.conf 2>/dev/null; then
               sudo sed -i '' '/anchor "claude-guard"/d' /etc/pf.conf
             fi ;;
  esac
  ok "旧安装已移除"
done
sudo pfctl -f /etc/pf.conf -E >/dev/null 2>&1 || true

say "安装出站熔断器"
. "$HERE/lib/install_guard.sh"
install_guard "$HERE" "$PROXY_PORT" ip-please-guard "${RELAUNCH_APP:-}" || die "断网保险安装或校验失败"
ok "保险已安装（豁免中，未武装）"

if [ "${SET_BROWSER_POLICIES:-1}" = "1" ]; then
  say "写入浏览器策略"
  BROWSER_BUNDLE_IDS="${BROWSER_BUNDLE_IDS:-com.google.Chrome com.brave.Browser}" \
    bash "$HERE/lib/browser-policies.sh" install || die "浏览器策略写入失败"
  ok "策略已写入（重启浏览器生效）"
fi

say "配置 Claude Code 代理"
python3 "$HERE/lib/claude_env.py" install "$PROXY_PORT" >/dev/null || die "写入 ~/.claude/settings.json 失败"
ok "配置已写入: ~/.claude/settings.json"

if [ "${DISABLE_IPV6:-1}" = "1" ]; then
  IFACE="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
  SERVICE="$(networksetup -listnetworkserviceorder | awk -v i="$IFACE" 'index($0,"Device: "i){print prev} {prev=$0}' | sed 's/^([0-9]*) //')"
  if [ -n "${SERVICE:-}" ]; then
    networksetup -setv6off "$SERVICE" >/dev/null 2>&1 && ok "关闭 $SERVICE 的 IPv6" || wrn "关闭 IPv6 失败，跳过"
  else
    wrn "未识别网络服务，跳过 IPv6"
  fi
fi

say "验证链路"
"$HERE/bin/ip-please" ip || die "出口 IP 画像异常"
"$HERE/bin/ip-please" dns || die "DNS 未正确接管"
"$HERE/bin/ip-please" doctor --pre >/dev/null || die "体检未通过（运行 bin/ip-please doctor 查看）"

say "武装断网保险"
rm -f "$PAUSE"
sleep 6
if sudo pfctl -a ip-please-guard -sr 2>/dev/null | grep -q '^block'; then
  wrn "规则非空：代理可能未就绪，检查后运行 ip-please guard status"
else
  ok "保险待命"
fi

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sf "$HERE/bin/ip-please" "$LOCAL_BIN/ip-please"
ln -sf "$HERE/bin/ip-please" "$LOCAL_BIN/airlock"   # 旧命令名兼容别名
if command -v ip-please >/dev/null 2>&1; then
  ok "命令已可用: $(command -v ip-please)"
else
  wrn "已链接到 $LOCAL_BIN/ip-please，但该目录不在 PATH 里"
fi

say "安装完成"
printf '  体检: %s/bin/ip-please doctor\n' "$HERE"
printf '  暂停: touch %s\n' "$PAUSE"
printf '  卸载: %s/uninstall.sh\n' "$HERE"
trap - EXIT
