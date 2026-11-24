# 小白安装指南（不需要懂命令行）

这份指南写给：**没用过终端、也不想看代码**的 macOS 用户。全程复制粘贴，约 5 分钟。

## 你需要准备

- 一台 Mac（macOS 12 以上）
- 这台 Mac 的**开机密码**（安装时会问一次）
- 能正常上网

## 第 1 步：打开「终端」

按 `Command + 空格`，输入 `终端`（或 `Terminal`），回车。会出现一个白底或黑底的小窗口，这就是终端。

> 找不到就用「访达 → 应用程序 → 实用工具 → 终端」。

## 第 2 步：复制这一行，粘贴，回车

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/zahT3/ip-please/main/scripts/quickstart.sh)"
```

复制方法：点上面代码块右上角的复制按钮；在终端里按 `Command + V` 粘贴，然后回车。

## 第 3 步：跟着提示走

脚本会依次做四件事：

1. 检查有没有 Homebrew（Mac 上装软件的工具）；没有会问你要不要装，输入 `y` 回车
2. 安装 ip-please
3. **安装系统侧防护**——这一步会要密码。输入时**屏幕上不会显示任何字符**，这是正常的，输完直接回车
4. 自动体检

## 第 4 步：看到「全部通过」就成了

最后屏幕上会出现类似：

```
▸ 链路与熔断器
  ✅  代理客户端           运行中
  ✅  熔断器               已加载

  全部通过
```

有黄色 ⚠️ 或红色 ❌ 也不代表坏，把截图发给维护者就行。

## 以后怎么用

日常只需要一条命令（同样复制粘贴到终端）：

```bash
ipp doctor
```

它会告诉你：出口 IP 干不干净、有没有泄漏、代理断了会不会漏真实地址。

## 常见问题

| 现象 | 怎么办 |
|---|---|
| 输入 `ipp` 提示 `command not found` | 关掉终端窗口，重新打开一个再试 |
| 提示要输入密码但看不到字 | 正常现象，直接输完回车 |
| 卡在 `Updating Homebrew` | 正常，等 1–3 分钟 |
| 安装完突然上不了网 | 在终端执行 `ipp panic`，网络会立刻恢复；然后跑 `ipp doctor` 看哪一步不对 |
| 提示 `Operation not permitted` | 系统设置 → 隐私与安全性 → 完全磁盘访问权限，把「终端」加进去 |
| 想暂停防护 | `ipp guard pause`（恢复：`ipp guard resume`） |
| 想彻底卸载 | `"$(brew --prefix ip-please)/libexec/uninstall.sh" && brew uninstall ip-please` |

## 这个脚本做了什么（安全说明）

- 只从 GitHub 官方仓库 `zahT3/ip-please` 下载安装
- 装完的工具有两个部分：命令行（`ipp`）和一个系统级防护（在代理断开时阻断出网，防止真实 IP 泄漏）
- **不收集任何数据、不上传任何信息**，代码全部开源，可以自己看

## 另一种方式：下载 .pkg 双击安装

1. 打开 <https://github.com/zahT3/ip-please/releases/latest>
2. 下载 `ip-please-<版本>-arm64.pkg`
3. 双击安装。如果提示"无法打开，因为无法验证开发者"：
   **右键点安装包 → 打开**，或到「系统设置 → 隐私与安全性 → 仍要打开」
4. 装完在终端执行 `ipp doctor`

> 说明：这个 .pkg 目前没有 Apple 开发者签名与公证（需要付费开发者账号），所以首次打开要手动放行一次；且只适用于 Apple Silicon（M 系列）Mac。Intel Mac 请用上面的一键脚本。

## 不想用一键脚本？

手动三步：

```bash
brew install zahT3/tap/ip-please
"$(brew --prefix ip-please)/libexec/install.sh"
ipp doctor
```
