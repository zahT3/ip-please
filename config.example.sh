#!/bin/bash
# 复制成 config.sh 后修改。不要在这里写密钥或订阅链接。

PROXY_PORT="${PROXY_PORT:-7890}"
EXPECT_COUNTRY="${EXPECT_COUNTRY:-TW}"
EXPECT_IP_PREFIX="${EXPECT_IP_PREFIX:-}"
FAKE_IP_PREFIX="${FAKE_IP_PREFIX:-198.18.}"
AI_GROUP="${AI_GROUP:-AI}"   # 填你客户端里 AI 相关策略组的名字

AI_DOMAINS="${AI_DOMAINS:-claude.ai claude.com anthropic.com api.anthropic.com console.anthropic.com platform.claude.com code.claude.com releases.claude.com downloads.claude.ai preview.claude.ai claudeusercontent.com claudemcpcontent.com statsig.anthropic.com statsig.com sentry.io ingest.sentry.io claude.googleapis.com}"
PIN_DOMAINS="${PIN_DOMAINS:-statsig.com claude.googleapis.com}"

PROFILE_DIR="${PROFILE_DIR:-$HOME/Library/Application Support/com.follow.clash/profiles}"
PROFILE_PATH="${PROFILE_PATH:-}"

DISABLE_IPV6="${DISABLE_IPV6:-1}"
SET_BROWSER_POLICIES="${SET_BROWSER_POLICIES:-1}"
BROWSER_BUNDLE_IDS="${BROWSER_BUNDLE_IDS:-com.google.Chrome com.brave.Browser}"
OUTPUT_STYLE="${OUTPUT_STYLE:-badge}"

# 熔断后是否尝试自动拉起代理客户端（留空 = 不拉起）。例：RELAUNCH_APP="FlClash"
RELAUNCH_APP="${RELAUNCH_APP:-}"

# 地区不一致时是否一律判失败（1=严格；0=仅中文/日文/韩文语言判失败）
FINGERPRINT_STRICT="${FINGERPRINT_STRICT:-0}"
