#!/usr/bin/env python3
"""给 Claude Code 写入/移除代理环境变量。

用法:
  claude_env.py install 7890
  claude_env.py remove
"""
import json
import os
import sys
import time

SETTINGS = os.path.expanduser("~/.claude/settings.json")
KEYS = ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY")


def load():
    if not os.path.exists(SETTINGS):
        return {}
    with open(SETTINGS, "r", encoding="utf-8") as f:
        return json.load(f)


def save(data):
    os.makedirs(os.path.dirname(SETTINGS), exist_ok=True)
    if os.path.exists(SETTINGS):
        backup = f"{SETTINGS}.bak-{time.strftime('%Y%m%d-%H%M%S')}"
        with open(SETTINGS, "rb") as src, open(backup, "wb") as dst:
            dst.write(src.read())
    with open(SETTINGS, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "install"
    data = load()
    env = data.setdefault("env", {})

    if action == "install":
        port = sys.argv[2] if len(sys.argv) > 2 else "7890"
        env.update({
            "HTTP_PROXY": f"http://127.0.0.1:{port}",
            "HTTPS_PROXY": f"http://127.0.0.1:{port}",
            "ALL_PROXY": f"socks5h://127.0.0.1:{port}",
            "NO_PROXY": "localhost,127.0.0.1,::1",
        })
    elif action == "remove":
        for k in KEYS:
            env.pop(k, None)
    else:
        print(__doc__, file=sys.stderr)
        return 64

    save(data)
    print(json.dumps({k: env.get(k) for k in KEYS if k in env}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
