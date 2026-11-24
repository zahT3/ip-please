#!/bin/bash
# 一键安装：检查环境 → 装 Homebrew 包 → 装系统侧熔断器 → 体检
# 用法（保住交互，别用 curl | bash）：
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/zahT3/ip-please/main/scripts/quickstart.sh)"
set -uo pipefail

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

say()  { printf '\n\033[1;36m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[1;32m✓ %s\033[0m\n' "$*"; }
warn() { printf '  \033[1;33m! %s\033[0m\n' "$*"; }
die()  { printf '  \033[1;31m✗ %s\033[0m\n' "$*"; exit 1; }
run()  { if [ "$DRY" = "1" ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }

ask() { # ask <prompt>  -> 读到 /dev/tty，兼容 bash -c "$(curl ...)"
  local reply=""
  if [ -r /dev/tty ]; then
    printf '  %s [y/N] ' "$1"
    read -r reply < /dev/tty || reply=""
  fi
  case "$reply" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

[ "$(uname -s)" = "Darwin" ] || die "这个脚本只支持 macOS（检测到 $(uname -s)）"
[ "$(uname -m)" = "arm64" ] && ARCH="Apple Silicon" || ARCH="Intel"
ok "macOS $(sw_vers -productVersion) / ${ARCH}"

say "第 1 步：检查 Homebrew"
if command -v brew >/dev/null 2>&1; then
  ok "已安装 Homebrew"
elif [ "$DRY" = "1" ]; then
  ok "[dry-run] 会安装 Homebrew"
else
  if ask "没有 Homebrew，现在安装吗？（需要管理员密码）"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || die "Homebrew 安装失败"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)" || true
  else
    die "需要 Homebrew。请先执行：/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  fi
fi

say "第 2 步：安装 ip-please"
run brew tap zahT3/tap || die "添加 tap 失败"
run brew install ip-please || die "安装失败"
ok "命令行工具已安装"

say "第 3 步：安装系统侧组件（会请求管理员密码）"
if [ "$DRY" = "1" ]; then
  ok "[dry-run] brew --prefix ip-please/libexec/install.sh"
elif [ -x "$(brew --prefix ip-please)/libexec/install.sh" ]; then
  "$(brew --prefix ip-please)/libexec/install.sh" || die "系统侧组件安装失败"
else
  die "找不到 install.sh，请重跑一次或到项目页反馈"
fi

say "第 4 步：体检"
if [ "$DRY" = "1" ]; then
  ok "[dry-run] ipp doctor"
else
  ipp doctor || warn "体检有失败项，把上面的输出发给维护者即可"
fi

say "完成"
printf '  日常体检: ipp doctor\n'
printf '  暂停防护: ipp guard pause\n'
printf '  恢复防护: ipp guard resume\n'
printf '  卸载:     "$(brew --prefix ip-please)/libexec/uninstall.sh" && brew uninstall ip-please\n'
