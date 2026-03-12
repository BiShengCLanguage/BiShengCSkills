#!/bin/bash
# bsc-fix-qualifiers.sh — PostToolUse hook for Claude Code
# Auto-fixes _Owned/_Borrow qualifier placement in .cbs files
#
# Fixes patterns like:
#   _Owned char*  → char *_Owned
#   _Owned int*   → int *_Owned
#   _Borrow int*  → int *_Borrow
#
# Install: Add to .claude/settings.local.json or ~/.claude/settings.json:
#   "hooks": {
#     "PostToolUse": [{
#       "matcher": "Write|Edit",
#       "hooks": [{
#         "type": "command",
#         "command": "bash /path/to/bsc-fix-qualifiers.sh"
#       }]
#     }]
#   }

set -euo pipefail

# Read hook JSON from stdin
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

# Only process .cbs files
[[ "$FILE" == *.cbs ]] || exit 0
[[ -f "$FILE" ]] || exit 0

# Fix _Owned qualifier placement: _Owned TYPE* → TYPE *_Owned
# Handles: _Owned char*, _Owned int*, _Owned void*, _Owned struct Foo*, etc.
sed -i -E '
  s/\b_Owned\s+(unsigned\s+|signed\s+|const\s+|volatile\s+)*(char|short|int|long|float|double|void|struct\s+[A-Za-z_][A-Za-z0-9_]*)\s*\*/\1\2 *_Owned/g
  s/\b_Borrow\s+(unsigned\s+|signed\s+|const\s+|volatile\s+)*(char|short|int|long|float|double|void|struct\s+[A-Za-z_][A-Za-z0-9_]*)\s*\*/\1\2 *_Borrow/g
' "$FILE"
