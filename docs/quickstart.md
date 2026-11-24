# Quickstart (no CLI experience needed)

For macOS users who have never opened a terminal.

**Before you start:** the installer only sets up protection. It does not install a proxy client or log you in.

Order on a new Mac:

1. Install a proxy client (FlClash etc.), import your subscription, enable System Proxy + TUN
2. Run the installer below (it checks that port 7890 is listening)
3. Install Claude Code / Claude Desktop and sign in
4. `ipp doctor` should be all green

1. Press `Command + Space`, type `Terminal`, hit Enter.
2. Copy this line, paste with `Command + V`, press Enter:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/zahT3/ip-please/main/scripts/quickstart.sh)"
```

3. Follow the prompts. It installs Homebrew if missing, installs `ip-please`, installs the system-side breaker (asks for your Mac password once — nothing shows while typing), then runs a health check.
4. When you see `全部通过` / all-pass, you are done.

Daily use:

```bash
ipp doctor
```

Something broke the network? `ipp panic` releases the breaker immediately.

Uninstall:

```bash
"$(brew --prefix ip-please)/libexec/uninstall.sh" && brew uninstall ip-please
```

## Or download the .pkg

1. Open <https://github.com/zahT3/ip-please/releases/latest>
2. Download `ip-please-<version>-arm64.pkg`
3. Double-click it. If macOS says it cannot verify the developer: right-click the package → Open, or allow it in System Settings → Privacy & Security → Open Anyway
4. Run `ipp doctor` afterwards

The package is currently unsigned and un-notarized (needs a paid Apple Developer account), so it needs one manual approval; it is Apple Silicon only. Intel Macs should use the one-line installer above.

## Telemetry

| Client | Telemetry |
|---|---|
| **Claude Code** | Disabled. The installer writes `DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`, `DISABLE_FEEDBACK_COMMAND`, `CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` into `~/.claude/settings.json`. Keep telemetry with `IP_PLEASE_KEEP_TELEMETRY=1 ./install.sh` |
| **Claude Desktop** | Cannot be disabled. There is no public switch for the desktop app (only enterprise managed config). The tool pins its traffic to the same egress so no real IP leaks; usage data is still sent as designed |

The installer never collects or uploads data; the full source is in this repository.
