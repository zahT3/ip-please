# ip-please

[![CI](https://github.com/zahT3/ip-please/actions/workflows/ci.yml/badge.svg)](https://github.com/zahT3/ip-please/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**macOS 下的 AI 账号出口身份审计与防泄漏熔断 CLI**

[English](README.md) · [变更记录](CHANGELOG.md) · [安全策略](SECURITY.md)

![IP, please —— 给你的出站流量设一道边检](docs/poster.svg)

每次出网都是一次过关。`ip-please` 就在你的 Mac 上设这道关口：每个连接都要出示证件（ASN、geo、欺诈评分、反向域名），几条已知的夹带路线会被逐个搜身（WebRTC、QUIC、明文 DNS、未收敛的策略组），代理链路一断就锁死舱门，而不是让真实地址大摇大摆走出去。

工具与上层服务解耦，只审计并控制本机的出站状态。

> 仓库名是把「ID, please」改一个字母：**IP, please**。底下的隐喻还是气闸——失压时锁死舱门。

![ip-please doctor](docs/demo.svg)

## 威胁模型

| 面 | 观测方 | 可见信号 |
|---|---|---|
| 出口身份 | 服务端 / CDN / 风控 | IP、ASN、geo、reverse DNS、欺诈评分、请求时序 |
| 泄漏路径 | 本机 | WebRTC 非代理 UDP、QUIC、明文 DNS、未收敛的策略组 |
| 故障域 | 代理客户端 | 进程崩溃或重启窗口内的透明直连 |

## 边界：保号，不是 IP 洁癖

目标是让账号活着，手段是管住出站面。它只覆盖网络侧的封号信号，其余不管。

| 封号信号 | 是否覆盖 | 手段 |
|---|---|---|
| 出口 IP 信誉（机房 / VPN 标记 / 欺诈评分） | 是 | `ip` 审计 + 固定住宅节点 |
| 泄漏暴露（WebRTC、QUIC、明文 DNS、旁路域名） | 是 | `dns` + `egress` 断言，`guard` fail-closed |
| 环境不一致（时区 / 语言 / geo） | 是 | `fingerprint` |
| 本地残留（cookie、token、设备痕迹） | 部分 | `residue` 扫描 + 手动清理 |
| 支付方式或账单地区不一致 | 否 | 不在工具范围 |
| 账号共享、多设备 IP 漂移 | 否 | 属使用纪律，不属工具 |
| 行为与内容触发 | 否 | 不在工具范围 |
| 第三方会话工具（用量面板、中转站） | 否 | 卸掉它们 |

## 设计约束

1. **出口可验证** —— 实时读取实际出口属性，并与预期配置逐项比对。
2. **泄漏面可枚举** —— 逐项断言四类已知旁路，替代经验假设。
3. **故障可收敛** —— 代理失活时对 Web 流量执行 fail-closed 阻断，覆盖客户端默认的 fail-open 行为。
4. **自身可恢复** —— 阻断路径内置豁免标记与 TTL 自动回退，保留运维接管通道。

## 安装

```bash
git clone https://github.com/zahT3/ip-please
cd ip-please
cp config.example.sh config.sh   # PROXY_PORT / EXPECT_COUNTRY / PROFILE_DIR
./install.sh                     # pause -> install -> verify -> arm
```

`install.sh` 严格按序执行：先写入豁免标记，再修改任何网络配置；校验失败即中止生效，异常退出时保留豁免状态。

安装完成后可执行文件软链至 `~/.local/bin/ip-please`。

Homebrew（tap 仓库发布后可用）：

```bash
brew install zahT3/tap/ip-please
```

## 命令

| 命令 | 语义 |
|---|---|
| `ip-please doctor` | 全量状态审计；任一检查项偏离预期即返回非零退出码 |
| `ip-please ip` | 出口身份核验：ASN、reverse DNS、欺诈评分、住宅/机房属性、geo |
| `ip-please dns` | 解析路径断言：验证 `claude.ai` 等域名解析结果落于 fake-ip 网段 |
| `ip-please egress [--fix]` | 出口收敛：审计目标 AI 域名是否命中单一策略组；`--fix` 自动归并旁路域名 |
| `ip-please fingerprint` | 本机环境一致性：校验时区、语言、地区设置与出口 geo 是否对齐 |
| `ip-please risk` | 风控探测：检测目标站点是否返回 Cloudflare challenge |
| `ip-please guard <sub>` | 出站熔断器控制：`status` / `install` / `pause` / `resume` / `remove` / `test` / `test-soft` |
| `ip-please panic` | 应急解除熔断（网络被阻断时使用） |
| `ip-please residue [--purge]` | 本地残留扫描与清理（切换账号前执行） |

全局参数：`--profile <path>` 指定订阅文件；`--plain` / `--stack` / `--badge` / `--unicode` 切换输出格式。

## 出站熔断器

由 launchd 每 5 秒调度一次：

```
        port up                        port up
  ┌──────────────────► STANDBY ◄──────────────────┐
  │                      │                        │
  │                 port down                     │
  │                      ▼                        │
  │             GRACE(120s) ──▶ BLOCK ──900s──▶ OPEN(3600s)
  │                              │                 │
  └──────────────────────────────┴─────────────────┘
                 pause flag ──▶ clear(BLOCK|OPEN)
```

| 状态 | 行为 |
|---|---|
| STANDBY | pf anchor 规则为空，无转发开销 |
| GRACE | 代理重启宽限期，不触发阻断 |
| BLOCK | 阻断出站 TCP 80/443/8080/8443 与 UDP 443/3478/5349/19302 |
| OPEN | TTL 回退：放行出站 3600 秒并记录系统日志，避免主机失联 |
| pause | 清空 pf 规则并重置冷却计时器，随时响应人工介入 |

规则加载后校验 `pfctl -a ip-please-guard -sr` 的条数；pf anchor 缺失时自动注册并重载 `pf.conf`；操作失败只写系统日志，不输出成功状态。

熔断器只阻断、不启动客户端；需要它在阻断时尝试拉起代理，配 `RELAUNCH_APP="FlClash"`（默认关闭，每次阻断仅尝试一次）。

**运维规程：`ip-please guard pause` → 执行变更 → 状态验证 → `ip-please guard resume`。** 该时序受自动化测试约束。

## 为什么是定时巡检而不是常驻进程

每次 tick 约 40 ms（含 fork 出十个辅助进程），每 5 秒一次，两次之间**常驻内存为 0**。常驻 root 守护进程则要 7×24 保留 3–5 MB 内存与更大的攻击面，崩溃会丢内存态，更新逻辑必须重启进程。定时方案是无状态的（状态全在 `/var/run`）、幂等的、替换文件即可升级。

## 测试

```bash
make check     # shellcheck + python/bash 语法 + 22 条回归断言
```

- `guard_state_test.sh` —— 状态机：STANDBY、BLOCK、pause、TTL 回退与 pf anchor 自愈
- `rules_parser_test.sh` —— 规则解析：字符转义、后缀匹配、缺失 `rules:` 的退出码、`--fix` 幂等
- `install_order_test.sh` —— 安装时序：pause 先于安装、校验通过后才激活、失败即中止、修改 `pf.conf` 具备 sudo 权限

## 依赖

macOS 原生环境：bash 3.2、pfctl、launchctl、curl、python3（由 Xcode CLT 提供）。

## 贡献与许可

- 贡献指南 [CONTRIBUTING.md](CONTRIBUTING.md)
- 行为准则 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- 变更记录 [CHANGELOG.md](CHANGELOG.md)
- 安全策略 [SECURITY.md](SECURITY.md)
- 许可证 [MIT](LICENSE)

## 限制

- 仅支持 macOS。
- 需自行配置代理客户端（支持 FlClash / Clash Verge Rev / mihomo / sing-box）。
- `egress --fix` 直接修改本地订阅文件；外部更新订阅后需重新执行，未重跑前 `doctor` 会报告状态偏离。
- 存在多个配置文件时默认读取最新 mtime 文件，多配置场景需用 `--profile` 显式指定。
- 不含移动端支持（iOS/Android 系统级 VPN 接口无此类旁路泄漏路径）。
