.PHONY: help test lint check audit install uninstall

help:
	@printf 'make test      运行全部回归测试\n'
	@printf 'make audit     扫描个人数据/密钥残留\n'
	@printf 'make lint      shellcheck + python 语法检查\n'
	@printf 'make check     test + lint\n'
	@printf 'make install   安装（需 sudo，会先写豁免标记）\n'
	@printf 'make uninstall 卸载\n'

test:
	@bash tests/run_all.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -S warning bin/ip-please lib/*.sh scripts/*.sh install.sh uninstall.sh tests/*.sh && echo 'shellcheck: OK'; \
	else \
		echo 'shellcheck 未安装，跳过（brew install shellcheck）'; \
	fi
	@python3 -m py_compile lib/ip_please.py lib/claude_env.py && echo 'python 语法: OK'
	@for f in bin/ip-please lib/*.sh scripts/*.sh install.sh uninstall.sh tests/*.sh; do bash -n "$$f" || exit 1; done
	@echo 'bash 语法: OK'

audit:
	@python3 scripts/audit_pii.py

check: test lint audit

install:
	@./install.sh

uninstall:
	@./uninstall.sh
