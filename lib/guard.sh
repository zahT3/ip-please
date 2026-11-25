#!/bin/bash
# 代理失效时阻断直连，防止真实 IP 泄漏。由 launchd 每 5 秒调用一次。
set -u

CONF="${IP_PLEASE_CONF:-/etc/ip-please/guard.conf}"
# shellcheck source=/dev/null
[ -r "$CONF" ] && . "$CONF"

ANCHOR="${GUARD_ANCHOR:-ip-please-guard}"
PORT="${GUARD_PROXY_PORT:-7890}"
PORTS_TCP="${GUARD_PORTS_TCP:-80 443 8080 8443}"
PORTS_STUN="${GUARD_PORTS_STUN:-443 3478 5349 19302}"
GRACE="${GUARD_GRACE:-120}"
TTL="${GUARD_TTL:-900}"
COOLDOWN="${GUARD_COOLDOWN:-3600}"
RELAUNCH_APP="${GUARD_RELAUNCH_APP:-}"

PF_CONF="${IP_PLEASE_PF_CONF:-/etc/pf.conf}"
PFCTL="${IP_PLEASE_PFCTL:-/sbin/pfctl}"
NC="${IP_PLEASE_NC:-/usr/bin/nc}"
IFCONFIG="${IP_PLEASE_IFCONFIG:-/sbin/ifconfig}"
TUN_PATTERN="${GUARD_TUN_PATTERN:-198.18.}"
RUNDIR="${IP_PLEASE_RUN:-/var/run}"
STATE="$RUNDIR/$ANCHOR.state"
RELAUNCH_MARK="$RUNDIR/$ANCHOR.relaunch"
CU=$(/usr/bin/stat -f %Su /dev/console 2>/dev/null)
BLOCKED="$RUNDIR/$ANCHOR.blocked"
OPEN="$RUNDIR/$ANCHOR.open"

log() { /usr/bin/logger -t "$ANCHOR" "$*"; }

console_home() {
  case "$CU" in ''|root|loginwindow) return 1 ;; esac
  /usr/bin/dscl . -read "/Users/$CU" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}'
}

_pause_active() {
  local f="$1" line until
  [ -e "$f" ] || return 1
  line=$(/usr/bin/head -1 "$f" 2>/dev/null)
  case "$line" in
    until=*)
      until=${line#until=}
      case "$until" in ''|*[!0-9]*) return 0 ;; esac
      if [ "$(/bin/date +%s)" -ge "$until" ]; then
        rm -f "$f" 2>/dev/null
        log "pause expired -> re-armed"
        return 1
      fi ;;
  esac
  return 0
}

paused() {
  local h
  # 测试/沙箱：IP_PLEASE_HOME 显式指定时只看它，避免读到真实用户的豁免文件
  if [ -n "${IP_PLEASE_HOME:-}" ]; then
    _pause_active "$IP_PLEASE_HOME/.ip-please-pause"
    return
  fi
  _pause_active "/etc/ip-please/pause" && return 0
  h=$(console_home) || return 1
  [ -n "$h" ] && _pause_active "$h/.ip-please-pause"
}

tun_up() {
  [ -z "$TUN_PATTERN" ] && return 0
  "$IFCONFIG" 2>/dev/null | /usr/bin/grep -q "inet ${TUN_PATTERN}"
}

rules_count() { $PFCTL -a "$ANCHOR" -sr 2>/dev/null | /usr/bin/grep -c '^block'; }

clear_rules() { $PFCTL -a "$ANCHOR" -F rules >/dev/null 2>&1; rm -f "$BLOCKED"; }

ensure_anchor() {
  /usr/bin/grep -q "anchor \"$ANCHOR\"" "$PF_CONF" 2>/dev/null && return 0
  printf 'anchor "%s"\n' "$ANCHOR" >> "$PF_CONF" 2>/dev/null || { log "cannot register anchor in $PF_CONF"; return 1; }
  $PFCTL -f "$PF_CONF" -E >/dev/null 2>&1 || { log "pf reload failed"; return 1; }
  log "anchor registered"
}

apply_block() {
  ensure_anchor || return 1
  local tcp stun
  tcp=$(printf '%s' "$PORTS_TCP" | tr ' ' ',')
  stun=$(printf '%s' "$PORTS_STUN" | tr ' ' ',')
  $PFCTL -a "$ANCHOR" -f - >/dev/null 2>&1 <<RULES || { log "pfctl load failed"; return 1; }
block drop out quick inet proto tcp to any port { $tcp }
block drop out quick inet proto udp to any port { $stun }
RULES
  [ "$(rules_count)" -ge 1 ] || { log "rules not verified after load"; return 1; }
  log "proxy down -> web ports blocked"
}

now=$(/bin/date +%s)

if paused; then clear_rules; rm -f "$OPEN"; exit 0; fi

if "$NC" -z -G 1 127.0.0.1 "$PORT" >/dev/null 2>&1; then
  printf '%s\n' "$now" > "$STATE"
  clear_rules
  rm -f "$OPEN" "$RELAUNCH_MARK"
  exit 0
fi

[ -f "$STATE" ] || { printf '%s\n' "$now" > "$STATE"; exit 0; }

last=$(/bin/cat "$STATE" 2>/dev/null || echo 0)
if ! tun_up; then
  # TUN 已消失 = 流量可能直接走物理网卡，宽限期不再安全，立即阻断
  log "tun interface missing -> skip grace"
  last=0
fi
[ $((now-last)) -lt "$GRACE" ] && exit 0

if [ -f "$OPEN" ]; then
  until_open=$(/bin/cat "$OPEN" 2>/dev/null || echo 0)
  if [ "$now" -lt "$until_open" ]; then clear_rules; exit 0; fi
  rm -f "$OPEN" "$BLOCKED"
fi

if [ -f "$BLOCKED" ]; then
  b=$(/bin/cat "$BLOCKED" 2>/dev/null || echo 0)
  if [ $((now-b)) -gt "$TTL" ]; then
    clear_rules
    printf '%s\n' $((now+COOLDOWN)) > "$OPEN"
    log "TTL exceeded -> fail-open for ${COOLDOWN}s"
    exit 0
  fi
else
  printf '%s\n' "$now" > "$BLOCKED"
fi

apply_block || exit 1

# 可选：阻断持续时尝试拉起代理客户端（每次阻断只尝试一次）
if [ -n "$RELAUNCH_APP" ] && [ ! -f "$RELAUNCH_MARK" ]; then
  case "$CU" in ''|root|loginwindow) : ;; *)
    uid=$(/usr/bin/id -u "$CU" 2>/dev/null)
    if [ -n "$uid" ]; then
      /bin/launchctl asuser "$uid" /usr/bin/open -a "$RELAUNCH_APP" >/dev/null 2>&1 ||
        /usr/bin/sudo -u "$CU" /usr/bin/open -a "$RELAUNCH_APP" >/dev/null 2>&1
      log "relaunch requested: $RELAUNCH_APP"
    fi
    : > "$RELAUNCH_MARK"
    ;;
  esac
fi
