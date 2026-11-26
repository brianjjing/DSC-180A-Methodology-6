#!/usr/bin/env bash
# Send check_leakage.sh the payload Claude Code sends after an Edit of $1,
# so its stderr and exit code can be recorded even for a hand-seeded fault.
set -uo pipefail

file="${1:-src/features.py}"
printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/%s"}}' "$PWD" "$file" \
  | CLAUDE_PROJECT_DIR="$PWD" bash .claude/hooks/check_leakage.sh
echo "[hook exit: $?]"
