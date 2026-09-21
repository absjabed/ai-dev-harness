---
description: Generate a standup report from recent git activity
allowed-tools: Read, Bash, mcp__atlassian
---
@.ai/agents/pm-agent.md

**Scope determination (do this first):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, focus git log on that scope's directory.
2. Otherwise: standup covers all recent activity — default to fullstack (search `src/Api/` and `src/Web/` both).

Generate a standup report for: $ARGUMENTS (default: today)

Format:
## Yesterday
[commits and changes from yesterday]

## Today
[work in progress from uncommitted changes or recent branches]

## Blockers
[any failed tests, unresolved conflicts, or open questions]
