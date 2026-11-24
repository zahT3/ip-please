#!/bin/bash
# 写入浏览器策略：关闭非代理 UDP 的 WebRTC + 关闭 QUIC
# 注意：WebRtcIPHandling 属于 per-profile 策略，设备级目录会被 Chrome 忽略，
# 必须同时写到用户级目录 /Library/Managed Preferences/<user>/ 下。
set -u
ROOT_USER=$(/usr/bin/stat -f %Su /dev/console)
IDS="${BROWSER_BUNDLE_IDS:-com.google.Chrome com.brave.Browser}"

write_plist() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>WebRtcIPHandling</key>
  <string>disable_non_proxied_udp</string>
  <key>QuicAllowed</key>
  <false/>
</dict>
</plist>
EOF
}

install_policies() {
  for id in $IDS; do
    dev="/Library/Managed Preferences/$id.plist"
    write_plist | sudo tee "$dev" >/dev/null
    sudo chown root:wheel "$dev"; sudo chmod 644 "$dev"
    # 用户级副本，解决 per-profile 策略被忽略的问题
    usr="/Library/Managed Preferences/$ROOT_USER/$id.plist"
    write_plist | sudo tee "$usr" >/dev/null
    sudo chown root:wheel "$usr"; sudo chmod 644 "$usr"
    echo "  写入策略: $id"
  done
}

remove_policies() {
  for id in $IDS; do
    sudo rm -f "/Library/Managed Preferences/$id.plist" "/Library/Managed Preferences/$ROOT_USER/$id.plist"
    echo "  移除策略: $id"
  done
}

case "${1:-install}" in
  install) install_policies ;;
  remove)  remove_policies ;;
  *) echo "用法: $0 [install|remove]"; exit 1 ;;
esac
