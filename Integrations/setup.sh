#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
TASK_PYTHON="${CIRCUITDRAFT_PYTHON:-python3}"
"$TASK_PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else "Python 3.10+ is required; set CIRCUITDRAFT_PYTHON to a compatible interpreter.")'
"$TASK_PYTHON" -m venv .venv
.venv/bin/python -m pip install -r requirements-lock.txt
echo 'Installed local Python runtime. Register eplan_server.py and circuitdraft_server.py with your MCP client using .venv/bin/python.'
