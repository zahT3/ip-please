---
name: Bug 报告
about: 报告可复现的问题
labels: bug
---

## 环境

- macOS 版本（`sw_vers -productVersion`）：
- ip-please 版本（`ipp version`）：
- 代理客户端与版本：

## 现象

<!-- 实际行为 -->

## 期望

<!-- 期望行为 -->

## 复现步骤

1.
2.
3.

## 诊断输出

```
ipp doctor
```

<!-- 请先脱敏：出口 IP 可保留网段、去掉账号信息 -->

## 相关日志

```
sudo log show --last 10m --predicate 'process == "ip-please-guard"' | tail -20
```
