#!/bin/bash
# 构建未签名 .pkg：把工具装到 /usr/local/ip-please，装完自动装系统侧组件。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=$(/usr/bin/awk -F'"' '/^VERSION=/{print $2}' "$HERE/bin/ip-please")
ARCH=$(uname -m)
OUT="$HERE/dist"
ROOT=$(mktemp -d)
SCRIPTS=$(mktemp -d)
trap 'rm -rf "$ROOT" "$SCRIPTS"' EXIT

mkdir -p "$ROOT/usr/local/ip-please" "$OUT"
export COPYFILE_DISABLE=1
cp -R "$HERE/bin" "$HERE/lib" "$HERE/docs" "$HERE/install.sh" "$HERE/uninstall.sh" \
      "$HERE/config.example.sh" "$HERE/README.md" "$HERE/README.zh-CN.md" "$HERE/LICENSE" \
      "$ROOT/usr/local/ip-please/"

mkdir -p "$ROOT/usr/local/bin"
cat > "$ROOT/usr/local/bin/ipp" <<'EOS'
#!/bin/bash
exec /usr/local/ip-please/bin/ip-please "$@"
EOS
for c in ipplz ip-please airlock; do cp "$ROOT/usr/local/bin/ipp" "$ROOT/usr/local/bin/$c"; done
chmod 755 "$ROOT/usr/local/bin/"*

xattr -cr "$ROOT" 2>/dev/null || true
dot_clean -m "$ROOT" 2>/dev/null || true
find "$ROOT" -name '._*' -delete
ditto --norsrc --noextattr "$HERE/packaging/pkg/postinstall" "$SCRIPTS/postinstall"
chmod +x "$SCRIPTS/postinstall"

PKG="$OUT/ip-please-${VERSION}-${ARCH}.pkg"
rm -f "$PKG"
pkgbuild --root "$ROOT" \
  --scripts "$SCRIPTS" \
  --identifier "com.zaht3.ip-please" \
  --version "$VERSION" \
  --install-location "/" \
  "$PKG"
echo "built: $PKG"
pkgutil --payload-files "$PKG" | head -8
