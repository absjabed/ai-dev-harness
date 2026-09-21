#!/usr/bin/env bash
# UserPromptSubmit hook — pre-injects branch + scope into Claude's context.
# stdout is automatically added to Claude's context for UserPromptSubmit hooks.
# Kept minimal: one line, < 100ms, no disk writes.

BRANCH="$(git branch --show-current 2>/dev/null || echo 'unknown')"
SCOPE="$(head -1 .ai/config/current-scope.md 2>/dev/null | sed 's/^# //' || echo 'Scope: auto')"
printf "[Context] Branch: %s | %s\n" "$BRANCH" "$SCOPE"
