#!/usr/bin/env bash
# PreToolUse hook — keeps the agent's HTTP requests and browser sessions off forbidden hosts.
# Registered in .claude/settings.json for Bash, PowerShell and the browser MCP tools
# (mcp__claude-in-chrome__*, and Playwright's tools whether from .mcp.json or a plugin).
# Config-driven: reads .claude/hooks/hooks.env. A blank E2E_FORBIDDEN_HOSTS skips every check.
# Exit 2 = hard block (Claude sees the stderr message). Exit 0 = allow.
#
# What it catches: an HTTP client in a shell command (curl, wget, httpie, xh, Invoke-WebRequest /
# Invoke-RestMethod — bare, by path, with .exe, quoted, or nested in bash -c / $(...) / backticks)
# or any browser-tool call whose input names a forbidden host. What it cannot catch: a test runner
# or script whose own config points at that host (e.g. a Playwright baseURL in a config file) —
# keep production URLs out of test config.
#
# It is deliberately global: the agent never calls or browses production, for any reason.
# Post-deploy production checks belong to a human or to CI.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$HOOK_DIR/hooks.env" ]] && source "$HOOK_DIR/hooks.env"

E2E_FORBIDDEN_HOSTS="${E2E_FORBIDDEN_HOSTS:-}"
[[ -z "$E2E_FORBIDDEN_HOSTS" ]] && exit 0

payload="$(cat)"

# Prints "<tool name>\n<text to inspect>": the command for shell tools, the whole input for MCP
# tools (so URLs nested inside a batch of browser actions are seen too).
PARSED="$(printf '%s' "$payload" | node -e '
let raw = "";
process.stdin.on("data", c => raw += c).on("end", () => {
  try {
    const j = JSON.parse(raw);
    const ti = j.tool_input || {};
    const name = j.tool_name || "";
    const shell = name === "Bash" || name === "PowerShell";
    const text = shell ? (ti.command || "") : JSON.stringify(ti);
    process.stdout.write(name + "\n" + text);
  } catch (_) { process.stdout.write("\n"); }
});
' 2>/dev/null || printf '\n')"

TOOL="$(printf '%s' "$PARSED" | head -n 1)"
TEXT="$(printf '%s' "$PARSED" | tail -n +2)"
[[ -z "$TEXT" ]] && exit 0

if [[ "$TOOL" == "Bash" || "$TOOL" == "PowerShell" ]]; then
  # Only HTTP clients matter here; a git remote or a log line naming the host is not a request.
  # A client name counts after a separator, quote, backtick or path segment, and before
  # whitespace, a quote, a backtick, a bracket or the end — optionally as name.exe.
  CLIENT_RE='(^|[^A-Za-z0-9_.-])(curl|wget|http|https|xh|invoke-webrequest|invoke-restmethod|iwr|irm)(\.exe)?([^A-Za-z0-9_.:-]|$)'
  printf '%s' "$TEXT" | grep -qiE "$CLIENT_RE" || exit 0
fi

for host in $E2E_FORBIDDEN_HOSTS; do
  if printf '%s' "$TEXT" | grep -qiF -- "$host"; then
    echo "BLOCKED: '$host' is a forbidden (production) host — see E2E_FORBIDDEN_HOSTS in .claude/hooks/hooks.env. The agent never sends requests to or browses production; post-deploy production checks are done by a human or by CI. For runtime verification use the Test environments URLs in .ai/config/project-config.md." >&2
    exit 2
  fi
done

exit 0
