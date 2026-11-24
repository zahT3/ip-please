# 贡献指南

## 开发环境

macOS + Xcode Command Line Tools。运行时依赖全部是系统自带组件（bash、pfctl、launchctl、curl、python3），不需要额外安装。

```bash
git clone <repo> && cd ip-please
cp config.example.sh config.sh     # config.sh 在 .gitignore 里，不会被提交
```

## 跑测试

```bash
make test      # 等价于 bash tests/run_all.sh
make lint      # shellcheck（未安装则跳过）
make check     # 两者都跑
```

改动涉及熔断器、规则解析或安装顺序时，必须同时更新对应测试。

## 提交前

`make check` 里的 `make audit` 会扫描个人数据与密钥残留（真实出口 IP、`/Users/<name>/` 路径、token 形态、非 noreply 邮箱）。CI 也跑这一步——不要为了过关而放宽正则，该脱敏的是内容。

## 约束

- **bash 3.2 兼容**：macOS 自带的是 bash 3.2，不要用关联数组、`mapfile`、`${var,,}` 等 4.0+ 特性
- **不改用户数据**：`egress --fix` 只允许在订阅文件里插入规则，且必须先备份
- **任何 `pf.conf` 编辑必须带 sudo**，失败要显式报错而不是静默跳过
- **安全控制不可简化掉**：熔断器的宽限、TTL 回退、豁免入口、锚点校验，任何一条都不能为了"代码更短"而删除
- 注释只保留解释外部约束的（平台行为、协议语义），不复述代码

## 给编码代理的指引

仓库根目录有 [AGENTS.md](AGENTS.md)（面向 agent 的约束）和 [CLAUDE.md](CLAUDE.md)（指向 AGENTS.md）。改代码前先读 AGENTS.md 的硬约束。

## 提交

- 一个 PR 一件事
- 提交信息用 conventional commits：`feat:` / `fix:` / `docs:` / `test:` / `chore:`
- PR 描述里写：动机、行为变化、验证方式（命令 + 结果）

## 版本

`CHANGELOG.md` 记用户可见变化；版本号在 `bin/ip-please` 的 `VERSION`。
