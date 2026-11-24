#!/bin/bash
# 运行全部回归测试
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
for t in "$HERE"/*_test.sh; do
  printf '\n\033[1;36m== %s ==\033[0m\n' "$(basename "$t")"
  bash "$t" || fail=$((fail + 1))
done
printf '\n'
if [ "$fail" -eq 0 ]; then printf '\033[1;32m全部测试通过\033[0m\n'; exit 0; fi
printf '\033[1;31m%d 个测试文件失败\033[0m\n' "$fail"; exit 1
