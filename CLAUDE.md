# CLAUDE.md

仓库级指引以 [AGENTS.md](AGENTS.md) 为准。要点：

- 提交前跑 `make check`（shellcheck + 22 条回归断言）
- bash 3.2 兼容，禁用 4.0+ 特性
- 安全边界（GRACE / TTL 回退 / 豁免入口 / 锚点校验）不可简化
- `/etc/pf.conf` 的编辑必须带 `sudo` 且失败要报错
- `config.sh` 已被 gitignore，不要提交
