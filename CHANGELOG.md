# Changelog

本文件格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [0.5.0] - 2026-11-25

### Changed
- **命令更名：`airlock` → `ip-please`**，与仓库名 `ip-please` 对齐；`airlock` 仍作为兼容别名安装
- 内部标识随之迁移：`/etc/ip-please`、`local.ip-please.guard`、`/usr/local/bin/ip-please-guard`、`~/.ip-please-pause`、`IP_PLEASE_*` 环境变量
- 安装器支持从 airlock / gecko / claude-guard 三代旧安装平滑迁移

## [0.5.1] - 2026-11-25

### Added
- 短命令 `ipp`（主用），并安装 `ipplz` / `ip-please` / `airlock` 别名；仓库名保持 `ip-please`

## [0.5.2] - 2026-11-25

### Added
- `--redact`：打印前把真实出口身份（IP / ASN / 反查 / 用户路径 / 订阅 profile / 时区地区 / 策略组名）替换成示例值，输出可直接截图分享
- `tests/redact_test.sh`：脱敏回归（敏感值必须消失、示例值必须出现、fake-ip 不被误改）

## [0.5.3] - 2026-11-25

### Changed
- 环境一致性：时区/地区不一致现在**计入失败**（之前只是警告，doctor 仍报"全部通过"），并给出期望时区
- 中文区出口 + 英文 locale 改为 INFO 提示（常见于开发机默认值）
- 风控探测：Cloudflare 挑战降为 INFO（无登录态探针的预期结果），只有两个站点都被挑战才计失败

### Added
- `tests/fingerprint_test.sh`：环境一致性判定的退出码与提示

## [0.5.4] - 2026-11-25

### Added
- 环境一致性解析 `AppleLocale` 的 `@rg=` 区域覆盖（如 `en_US@rg=sgzzzz` → 语言 en · 地区 US · 区域覆盖 SG），并新增「地区解码」输出行
- `FINGERPRINT_STRICT=1`：地区不一致一律判失败；默认只在 zh/ja/ko 语言下判失败
- `tests/fingerprint_test.sh` 扩展到 11 项断言

## [0.5.5] - 2026-11-25

### Added
- 安装时默认关闭 Claude Code 遥测（5 个环境变量），`IP_PLEASE_KEEP_TELEMETRY=1` 可保留
- quickstart 增加代理客户端预检（7890 未监听时给出安装指引，`--skip-proxy-check` 可跳过）
- 文档补充「安装器会改什么」与「能不能关掉遥测」两节
- `tests/claude_env_test.sh`

## [0.5.6] - 2026-11-25

### Added
- 订阅 profile 自动探测（FlClash / Clash Verge / ClashX / mihomo 等常见目录），`PROFILE_DIR` 可留空
- `ipp egress --fix` 写入前校验 `AI_GROUP` 是否存在，不存在则拒绝并列出可用策略组，避免写坏订阅
- 手册新增「客户端兼容性」章节 + QA：非 Clash 客户端能用哪些、不能用哪些

### Changed
- README 修正客户端支持表述：熔断/探测与客户端无关，`egress` 仅支持 Clash 系 YAML

## [0.5.7] - 2026-11-25

### Added
- 用户级配置 `~/.config/ip-please/config.sh`（brew 安装也能改 AI_GROUP / PROXY_PORT 等，不用动 libexec）

### Fixed
- `egress` 找不到 profile 时提示被命令替换吞掉、用户看不到错误

## [0.5.8] - 2026-11-25

### Added
- 出口探针与 AI 路径对齐：`ipp egress --fix` 会把 `ipinfo.io` / `api.scamalytics.com` 一起钉进 AI 策略组
- `ipp egress` 与 `ipp ip` 会提示「探针路径与 Claude 出口不一致」，避免把默认路由的结果当成 AI 出口

## [0.6.0] - 2026-11-25

### Added
- `--refresh`：跳过 10 分钟出口缓存，切节点后可立即复测
- 出口信息多源回退：ipinfo 限流/失败时自动改用 ip-api（国家、ASN、反查、hosting 标记），反查兜底用 `dig -x`
- 「网络类型」判定加入 hosting 标记与更多 ISP 反查关键词（bbtec / ocn / comcast 等）

### Fixed
- 切节点后 `ipp ip` 结果不变（缓存 + ipinfo 429 导致无法刷新）

## [0.6.1] - 2026-11-25

### Fixed
- 订阅文件发现逻辑：优先读取 FlClash 数据库里的当前 profile id，避免按 mtime 选中未使用的旧文件（导致 `--fix` 改错文件）
- 手册新增 QA：FlClash 升级后自定义脚本失效的排查与恢复

## [0.6.2] - 2026-11-25

### Changed
- `ipp egress` 改为审计 FlClash 运行时配置 `config.yaml`（含脚本注入规则），结果与实际生效路由一致；找不到运行时配置时回退到 profile
- `--fix` 在脚本已启用时会提示「自定义规则建议写进脚本」，避免被订阅更新覆盖

### Fixed
- 运行时配置包含脚本规则时，egress/探针路径误报（之前只看 profile 文件）

## [0.6.3] - 2026-11-25

### Changed
- 熔断器增加 TUN 感知：TUN 网卡消失（默认匹配 `198.18.` 网段）时跳过 120 秒宽限，立即阻断，缩小“客户端崩溃后直连”的泄漏窗口
- `GUARD_TUN_PATTERN` 可配置 TUN 网段；`GUARD_GRACE` 仍可调整宽限
- 手册新增 QA：宽限期到底会不会泄漏真实 IP

## [0.6.4] - 2026-11-25

### Fixed
- 安装中止：`install_guard` 生成 `guard.conf` 时，`RELAUNCH_APP` 为空会在 `pipefail` 下让管道返回 1，导致 install.sh 直接退出（brew 安装路径最容易触发）
- `install.sh` 现在也会读取 `~/.config/ip-please/config.sh`，brew 安装同样能拿到 `RELAUNCH_APP` 等偏好

### Added
- `tests/install_conf_test.sh`：guard.conf 生成的空/非空 relaunch 回归

## [0.6.5] - 2026-11-26

### Added
- `ipp recover [--restart]`：FlClash 崩溃后一键恢复（暂停熔断、关闭残留系统代理、DNS 从 198.18.x 恢复 DHCP、刷新缓存、可选重启客户端、等待就绪后恢复熔断）
- `ipp doctor` 新增「其他 TUN」检测：Tailscale / OpenVPN / WireGuard 同时运行会抢路由
- `tests/recover_test.sh`：健康/残留/带重启三组回归

### Fixed
- `ipp recover` 中 CJK 紧跟变量导致的 unbound variable

## [Unreleased]

### Added
- 手册新增「账号侧设置清单（手动）」：Help improve Claude、2FA、一号一出口、支付地区、会话 token 等 10 项
- 补 QA：「Help improve Claude」在哪关；澄清 Desktop 训练数据开关 vs 崩溃/分析遥测


### Added
- `docs/handbook.zh-CN.md`：101 手册（全自动 vs 手动对照、新机流程、15 条 QA、术语表）
- `docs/handbook.md`：英文精简版
- `docs/README.md`：文档地图；README 与 quickstart 增加入口


### Added
- `scripts/build_pkg.sh`：构建未签名 `.pkg`（装到 `/usr/local/ip-please`，postinstall 自动装系统侧组件）
- Release workflow 增加 macOS pkg 构建与上传
- `.pkg` 安装方式与 Gatekeeper 放行说明（中英）


### Added
- `scripts/quickstart.sh`：一键安装（检查环境 → 装 brew 包 → 装系统侧组件 → 体检），支持 `--dry-run`
- `docs/quickstart.zh-CN.md` / `docs/quickstart.md`：面向不熟悉命令行的用户的分步教程与常见问题
- README 顶部加入复制粘贴安装入口


### Added
- `docs/poster.svg`：模仿「ID, please / Papers, Please」的梗图，README 顶部展示
- README 增加「边界：保号，不是 IP 洁癖」表格，明确覆盖与不覆盖的封号信号


### Added
- 英文 README（`README.md`），中文版移入 `README.zh-CN.md`
- `docs/demo.svg`：由真实 `ip-please doctor` 输出生成的终端演示图
- `.github/workflows/release.yml`：打 `v*` tag 自动打包并发布源码 tarball
- Homebrew 公式模板 `packaging/homebrew/ip-please.rb`
- `CODE_OF_CONDUCT.md`、`AGENTS.md`、`CLAUDE.md`
- CI 增加 shellcheck 并通过全部告警修复

### Changed
- LICENSE 版权持有人改为 zahT3
- 仓库名定为 `ip-please`；命令名保持 `ip-please`（缩写无可读性，命令用语义名）

## [0.4.1] - 2026-11-25

### Added
- 熔断后可选自动拉起代理客户端（`RELAUNCH_APP`，默认关闭，每次阻断仅尝试一次）
- `ip-please guard test-soft`：无需 sudo 的完整演练（阻断 → 自动拉起 → 恢复），中断会自动收尾

### Changed
- 拉起 GUI 应用改用 `launchctl asuser`，失败再退回 `sudo -u`

## [0.4.0] - 2026-11-24

### Changed
- 项目更名为 ip-please（原 gecko）；守护进程、pf 锚点、配置目录、状态文件、环境变量全部随之迁移
- 安装器支持从更早的两代安装（gecko / claude-guard）平滑迁移
- 文案改为工程化表述：出站身份、出口收敛、环境一致性、出站熔断器

## [0.3.3] - 2026-11-24

### Changed
- IP 画像改用 HTTPS 数据源（ipinfo + scamalytics），新增欺诈评分与反向域名判定住宅线路

### Fixed
- 出口数据缓存未校验新鲜度，可能读到上一次运行的残留

## [0.3.2] - 2026-11-24

### Changed
- 输出改为 CJK 宽度精确对齐，新增 `--plain` / `--stack` / `--badge` 三种风格

## [0.3.1] - 2026-11-24

### Fixed
- 浏览器策略脚本未使用参数导致 `set -u` 报错、策略文件被写空
- 安装验证包含"保险已装载"检查，导致永远验证失败（新增 `--pre` 跳过）

## [0.3.0] - 2026-11-24

### Added
- 出站熔断器 v3：pf 锚点自愈、规则条数核对、暂停时清冷却窗口
- 单出口审计、环境一致性、风控探测、本地残留扫描
- 22 条回归断言（熔断状态机 / 规则解析 / 安装时序）

### Security
- 移除明文 HTTP 的 IP 查询
- 全部 `pf.conf` 编辑改为带 sudo，不再静默失败
