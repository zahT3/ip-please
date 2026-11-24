#!/bin/bash
# 安装/校验断网保险。被 install.sh 和 `ip-please guard install` 共用。
# 调用方必须已经持有 sudo 授权，并且已经创建了豁免文件。

install_guard() {
  local here="$1" proxy_port="$2" anchor="${3:-ip-please-guard}" relaunch="${4:-}" plist
  plist="/Library/LaunchDaemons/local.ip-please.guard.plist"

  sudo install -d -m 755 /etc/ip-please || return 1
  sudo install -m 755 "$here/lib/guard.sh" /usr/local/bin/ip-please-guard || return 1

  {
    printf 'GUARD_ANCHOR=%s\nGUARD_PROXY_PORT=%s\n' "$anchor" "$proxy_port"
    [ -n "$relaunch" ] && printf 'GUARD_RELAUNCH_APP=%s\n' "$relaunch"
  } | sudo tee /etc/ip-please/guard.conf >/dev/null || return 1
  sudo chmod 644 /etc/ip-please/guard.conf

  sudo install -m 644 "$here/lib/guard.plist" "$plist" || return 1
  sudo install -d -m 755 /etc/pf.anchors || return 1
  [ -f "/etc/pf.anchors/$anchor" ] || sudo install -m 644 /dev/null "/etc/pf.anchors/$anchor" || return 1

  if ! grep -q "anchor \"$anchor\"" /etc/pf.conf; then
    sudo cp /etc/pf.conf "/etc/pf.conf.bak-ip-please-$(date +%Y%m%d%H%M%S)" || return 1
    echo "anchor \"$anchor\"" | sudo tee -a /etc/pf.conf >/dev/null || return 1
  fi
  sudo pfctl -f /etc/pf.conf -E >/dev/null 2>&1

  sudo launchctl bootout system "$plist" >/dev/null 2>&1
  sudo launchctl bootstrap system "$plist" >/dev/null 2>&1 || return 1
  verify_guard
}

verify_guard() {
  launchctl print system/local.ip-please.guard >/dev/null 2>&1 || {
    printf '  launchd 未加载 local.ip-please.guard\n' >&2; return 1; }
  grep -q 'anchor "ip-please-guard"' /etc/pf.conf || {
    printf '  /etc/pf.conf 缺少 anchor 注册\n' >&2; return 1; }
  [ -f /etc/ip-please/guard.conf ] || { printf '  缺少 /etc/ip-please/guard.conf\n' >&2; return 1; }
  return 0
}

remove_guard() {
  local plist=/Library/LaunchDaemons/local.ip-please.guard.plist
  sudo launchctl bootout system "$plist" >/dev/null 2>&1
  sudo pfctl -a ip-please-guard -F rules >/dev/null 2>&1
  sudo rm -f "$plist" /usr/local/bin/ip-please-guard /etc/pf.anchors/ip-please-guard /etc/ip-please/guard.conf
  if grep -q 'anchor "ip-please-guard"' /etc/pf.conf 2>/dev/null; then
    sudo sed -i '' '/anchor "ip-please-guard"/d' /etc/pf.conf
  fi
  sudo pfctl -f /etc/pf.conf -E >/dev/null 2>&1
}
