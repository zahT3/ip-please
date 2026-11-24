#!/usr/bin/env python3
"""扫描仓库中不应提交的内容：真实出口 IP、个人主目录路径、密钥形态、非 noreply 邮箱。"""
import re
import subprocess
import sys

PATTERNS = [
    ("home-path", re.compile(r"/Users/[A-Za-z0-9._-]+/")),
    ("ssh-key", re.compile(r"BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE KEY")),
    ("token", re.compile(r"(sk-[A-Za-z0-9]{20,}|sk-or-v1-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})")),
    ("bearer", re.compile(r"Bearer [A-Za-z0-9._-]{20,}")),
    ("email", re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")),
    ("public-ip", re.compile(r"\b(\d{1,3}\.){3}\d{1,3}\b")),
]
ALLOW_IP = re.compile(r"^(10\.|127\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|198\.18\.|203\.0\.113\.|192\.0\.2\.|198\.51\.100\.|0\.0\.0\.0)")
ALLOW_EMAIL = re.compile(r"(noreply@github\.com|users\.noreply\.github\.com|example\.(com|net|org))$")


def tracked():
    out = subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout
    return [f for f in out.splitlines() if f]


def main():
    findings = []
    for path in tracked():
        try:
            text = open(path, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            for name, rx in PATTERNS:
                for m in rx.finditer(line):
                    hit = m.group(0)
                    if name == "public-ip":
                        if ALLOW_IP.match(hit):
                            continue
                        if m.start() > 0 and line[m.start() - 1] == "/":  # Chrome/158.0.0.0 这类版本号
                            continue
                    if name == "email" and ALLOW_EMAIL.search(hit):
                        continue
                    findings.append((path, lineno, name, hit))
    for path, lineno, name, hit in findings:
        print(f"{path}:{lineno}: [{name}] {hit}")
    if findings:
        print(f"\n发现 {len(findings)} 处可疑内容，请先脱敏再提交。", file=sys.stderr)
        return 1
    print("未发现个人数据或密钥残留 ✅")
    return 0


if __name__ == "__main__":
    sys.exit(main())
