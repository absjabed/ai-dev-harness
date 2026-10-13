---
description: Runtime verification on demand — API calls, a real-browser UI run, read-only DB checks — for ad-hoc work or any change
argument-hint: "[<feature-slug> | what changed]"
allowed-tools: Read, Write, Edit, Bash, mcp__claude-in-chrome, mcp__playwright
---
@.ai/workflows/runtime-verification.md

**Scope determination (do this first, before any other action):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise, infer scope from "$ARGUMENTS" and the changed files (`git diff HEAD --stat`, plus
   `git log -5 --stat` if the working tree is clean): server-side files → backend, UI files →
   frontend, both → fullstack. Truly ambiguous → ask the user.
3. Load `.ai/config/project-config.md` (its **Test environments** section is required) and the
   determined scope's `project-config.md` and `context/business-rules.md`.

Target: $ARGUMENTS

1. **What is being verified.** If "$ARGUMENTS" names a folder under `.ai/features/`, read its
   `requirement-spec.md`, `test-specs.md`, `deploy-notes.md` and `STATE.md` where they exist, and
   use the feature diff. Otherwise this is ad-hoc work: use the uncommitted diff (or the commits the
   user names) and "$ARGUMENTS" as the description. If neither tells you what the change is meant
   to do, ask the user in one question before planning.
2. **Tools.** UI checks prefer Claude in Chrome (the session must have been started with
   `claude --chrome` or have Chrome enabled by default), else Playwright MCP. DB checks need a
   read-only database MCP server granted in this command's `allowed-tools` (`/init-project` adds
   it); without one they are NOT RUN.
3. **If Test environments is unfilled** (`[FILL IN` still present), stop: tell the user which
   values are missing and offer to fill them with them. Never guess a URL.
4. **Plan, ask once, run, report, gate** — follow the playbook above exactly, in this session.
   Report path: `.ai/features/<slug>/test-specs/e2e-report.md` for a feature, otherwise
   `.ai/reports/e2e-<YYYY-MM-DD>-<short-slug>.md` (`date +%F` for the date).
5. **Finish** with the summary (PASS / FAIL / NOT RUN counts, every FAIL and NOT RUN), the report
   path, and the next step. This command never commits: when the checks were for uncommitted
   work, say whether it is ready to commit, or what blocks it. If a `STATE.md` exists, update its
   runtime verification phase and record any failure the user accepted, in their words.
