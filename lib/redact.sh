#!/bin/bash
# 脱敏输出流：把真实出口身份替换成可公开的示例值，保持可读性。
redact_stream() {
  local args=(
    -E
    -e 's/198\.18\./__F__/g'
    -e 's/127\.0\.0\.1/__LOOP__/g'
    -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/203.0.113.42/g'
    -e 's/__F__/198.18./g'
    -e 's/__LOOP__/127.0.0.1/g'
    -e 's#/Users/[^/[:space:]]+#~#g'
    -e 's#Application Support/com\.[A-Za-z.]+#Application Support/<client>#g'
    -e 's#profiles/[0-9]+\.yaml#profiles/<profile>.yaml#g'
    -e 's#(Asia|America|Europe|Australia|Africa)/[A-Za-z_]+#Europe/Amsterdam#g'
    -e 's/[a-z]{2}_[A-Z]{2}@rg=[a-z]+/en_NL/g'
    -e 's/\( "en-US", "[^"]+", "[^"]+"\)/( "en-US", "nl-NL")/'
    -e 's/^([[:space:]]*ASN[[:space:]]+).*/\1AS64500 Example Telecom/'
    -e 's/^([[:space:]]*reverse DNS[[:space:]]+).*/\1203-0-113-42.dynamic.example.net/'
    -e 's/^(.*时区对齐[[:space:]]+)[^[:space:]]+/\1Europe\/Amsterdam/'
    -e 's/^(.*地区对齐[[:space:]]+)[^[:space:]]+/\1en_NL/'
    -e 's/^(.*出口 geo[[:space:]]+)[A-Z]{2}/\1NL/'
    -e 's/^(.*出口国家[[:space:]]+)[A-Z]{2}/\1NL/'
    -e 's/^([[:space:]]+时区[[:space:]]+)[^[:space:]]+/\1Europe\/Amsterdam/'
    -e 's/^([[:space:]]+地区[[:space:]]+)[^[:space:]]+/\1en_NL/'
    -e 's/^([[:space:]]+语言[[:space:]]+).*/\1( "en-US", "nl-NL")/'
  )
  /usr/bin/sed "${args[@]}"
}
