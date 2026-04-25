#!/bin/bash
# bsc-log.sh — PreToolUse hook for the bisheng-c-skills plugin.
#
# Logs only BSC-specific events:
#   - Any Skill tool invocation whose skill name starts with "bsc-" or "c-to-bsc"
#   - Any Agent tool invocation whose subagent_type is in the BSC agent list
#
# Hook input arrives on stdin as JSON. We never block — always exit 0.
# Logfile defaults to ~/.claude/bsc-usage.log; override with BSC_LOG_FILE.

set -u

LOG_FILE="${BSC_LOG_FILE:-$HOME/.claude/bsc-usage.log}"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || exit 0

input="$(cat)"

tool_name=$(printf '%s' "$input" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -z "$tool_name" ] && exit 0

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

case "$tool_name" in
    Skill)
        skill=$(printf '%s' "$input" | sed -n 's/.*"skill"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        # Skills loaded from a plugin arrive prefixed as "<plugin>:<skill>"
        # (e.g. "bisheng-c-skills:bsc-ownership"). Match both forms.
        case "$skill" in
            bsc-*|c-to-bsc|bisheng-c-skills:bsc-*|bisheng-c-skills:c-to-bsc)
                printf '%s\tSkill\t%s\n' "$ts" "$skill" >> "$LOG_FILE"
                ;;
        esac
        ;;
    Agent)
        subagent=$(printf '%s' "$input" | sed -n 's/.*"subagent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        # Agents from a plugin may also arrive prefixed as "<plugin>:<agent>".
        case "$subagent" in
            bsc-planner|bsc-learn|bisheng-c-skills:bsc-planner|bisheng-c-skills:bsc-learn)
                printf '%s\tAgent\t%s\n' "$ts" "$subagent" >> "$LOG_FILE"
                ;;
        esac
        ;;
esac

exit 0
