# AGENTS.md

本文件面向在此仓库工作的编码代理。人类贡献者请看 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 这是什么

macOS 上的出站身份审计与 fail-closed 熔断 CLI。bash 3.2 + 少量 python3，无第三方依赖。

## 命令

```bash
make check      # shellcheck + python/bash 语法 + 22 条回归断言（提交前必跑）
make test       # 仅回归测试
make lint       # 仅语法与静态检查
bash tests/guard_state_test.sh   # 跑单个测试文件
ipp doctor  # 本机真实体检（会发起网络请求）
```

## 硬约束

1. **bash 3.2 兼容**：macOS 自带 bash 3.2。禁用关联数组、`mapfile`、`${var,,}`、`&>>` 等 4.0+ 特性。
2. **安全边界不可简化**：熔断器的 GRACE、TTL 回退、豁免入口、锚点校验、规则条数核对，任何一条都不得为了"代码更短"而删除或绕过。
3. **`/etc/pf.conf` 的任何编辑必须带 `sudo`**，失败要显式报错，不许 `2>/dev/null` 吞掉。
4. **不写入用户数据**：`egress --fix` 只允许在订阅文件里插入规则，且必须先备份。
5. **不提交密钥或个人信息**：`config.sh` 在 `.gitignore` 里；仓库内不得出现真实出口 IP、账号、token。
6. **注释只解释外部约束**（平台行为、协议语义、工具指令），不复述代码。

## 改动规范

- 动了 `lib/guard.sh`、`lib/ip_please.py` 的解析逻辑、`lib/redact.sh` 的脱敏规则、或 `install.sh` 的顺序 → 必须同步更新 `tests/` 下对应文件。
- 版本号在 `bin/ip-please` 的 `VERSION`；用户可见变化写进 `CHANGELOG.md` 的 `## [Unreleased]`。
- 提交信息用 conventional commits：`feat:` / `fix:` / `docs:` / `test:` / `chore:`。
- 文档改动：中文在 `README.zh-CN.md`，英文在 `README.md`；两边的命令与状态机必须一致。

## 网络中断类操作的前置检查（强制）

任何可能中断代理、TUN 或防火墙的操作（暂停熔断、重启 FlClash、改 TUN/DNS、`ipp recover --restart`、`launchctl` 改动）之前：

1. 先运行 `ipp activity`。返回非 0（Claude Desktop / Claude CLI / 代理连接 / 5 分钟内有写入）时，**停止并告知用户**，除非用户明确要求继续。
2. 暂停熔断必须带时限：`ipp guard pause --for 180`，禁止裸 `pause`（不带 `--force` 时工具也会拒绝）。
3. 能用热重载就不要重启客户端；必须重启时提前说明，并确认用户没有正在进行的会话。
4. 操作结束后立刻 `ipp guard resume`，再跑 `ipp guard status` 复核（已加载 + 无豁免）。
5. 紧急恢复网络用 `ipp panic`，它不受上述门禁限制，但同样会提示 Claude 活动风险。

不要用 `pkill -f FlClashCore` 之类的强杀；崩溃时用 `ipp recover`。
