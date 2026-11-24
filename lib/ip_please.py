#!/usr/bin/env python3
"""ip-please 的 Python 辅助：一个进程做一件事，避免 shell 里重复起解释器。

子命令:
  ipjson            从 stdin 读取 ipinfo JSON，输出 cc\torg\thostname
  rules <profile>   stdout: "domain<TAB>group" 若干行 + "GROUPS<TAB>n"
                    exit 0=单一策略组 1=多策略组 2=解析失败
  fix <profile> <group> <domain>...   把规则插到 rules: 之后，输出插入条数
"""
import json
import os
import re
import sys

ESC_U = re.compile(r'\\U([0-9A-Fa-f]{8})')
ESC_u = re.compile(r'\\u([0-9A-Fa-f]{4})')


def unescape(s):
    s = ESC_U.sub(lambda m: chr(int(m.group(1), 16)), s)
    return ESC_u.sub(lambda m: chr(int(m.group(1), 16)), s)


def split_rules(path):
    lines = open(path, encoding='utf-8', errors='ignore').read().split('\n')
    start = next((i for i, l in enumerate(lines) if l.strip() == 'rules:'), None)
    if start is None:
        return None, None
    rules = []
    for line in lines[start + 1:]:
        t = line.strip()
        if not t.startswith('- '):
            if t == '':
                continue
            break
        rules.append(unescape(t[2:].strip().strip('"')))
    return lines, rules


def match(rules, domain):
    for r in rules:
        p = r.split(',')
        kind = p[0]
        if kind == 'MATCH':
            return r
        if len(p) < 2:
            continue
        if kind == 'DOMAIN' and domain == p[1]:
            return r
        if kind == 'DOMAIN-SUFFIX' and (domain == p[1] or domain.endswith('.' + p[1])):
            return r
        if kind == 'DOMAIN-KEYWORD' and p[1] in domain:
            return r
    return None


def group_names(path):
    """读取 proxy-groups 里的策略组名，找不到该段时返回 []。"""
    lines = open(path, encoding='utf-8', errors='ignore').read().split('\n')
    names, inside = [], False
    for line in lines:
        if re.match(r'^proxy-groups:\s*$', line):
            inside = True
            continue
        if inside:
            if line and not line[0].isspace():
                break
            m = re.match(r'\s*-\s*name:\s*(.+?)\s*$', line)
            if m:
                names.append(unescape(m.group(1).strip().strip('"')))
    return names


def cmd_ipjson():
    data = json.load(sys.stdin)
    host = data.get('hostname') or ''
    print('\t'.join([
        str(data.get('country') or ''),
        str(data.get('org') or ''),
        host if host != data.get('ip') else '',
    ]))


def cmd_rules(argv):
    mask = os.environ.get("IP_PLEASE_REDACT") == "1"
    domains = argv[1:]
    lines, rules = split_rules(argv[0])
    if rules is None:
        print('PARSE_ERROR', file=sys.stderr)
        return 2
    groups = {}
    for d in domains:
        r = match(rules, d)
        g = r.rsplit(',', 1)[-1].strip() if r else '(无匹配)'
        if mask and g != '(无匹配)':
            g = 'AI-policy'
        groups.setdefault(g, []).append(d)
        print(f'{d}\t{g}')
    print(f'GROUPS\t{len(groups)}')
    return 0 if len(groups) == 1 else 1


def cmd_fix(argv):
    path, group, domains = argv[0], argv[1], argv[2:]
    names = group_names(path)
    if names and group not in names:
        sys.stderr.write("策略组不存在: %s\n可用: %s\n" % (group, ", ".join(names)))
        return 3
    lines, rules = split_rules(path)
    if rules is None:
        print('PARSE_ERROR', file=sys.stderr)
        return 2
    body = '\n'.join(lines)
    start = next(i for i, l in enumerate(lines) if l.strip() == 'rules:')
    added = 0
    for d in domains:
        if f'DOMAIN-SUFFIX,{d},{group}' in body:
            continue
        lines.insert(start + 1, f'  - "DOMAIN-SUFFIX,{d},{group}"')
        start += 1
        added += 1
    if added:
        open(path, 'w', encoding='utf-8').write('\n'.join(lines))
    print(added)
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 64
    cmd, argv = sys.argv[1], sys.argv[2:]
    if cmd == 'ipjson':
        return cmd_ipjson() or 0
    if cmd == 'rules':
        return cmd_rules(argv)
    if cmd == 'fix':
        return cmd_fix(argv)
    print(f'unknown subcommand: {cmd}', file=sys.stderr)
    return 64


if __name__ == '__main__':
    sys.exit(main())
