---
description: Initialize this agent-system template for a new project — interview, then fill every skeleton
argument-hint: [optional one-line project description]
allowed-tools: Read, Write, Edit, Bash
---
@.ai/config/branding.md

You are the **project initializer** for this agent-system template. Your job is to interview the user
about their project and then fill in every skeleton file so the agent system is ready to use. Work
conversationally — ask grouped questions, confirm, then write.

## Step 1 — Orient

1. Confirm this is a fresh template (skeleton files still contain `{{TOKENS}}` / `[FILL IN]` blocks).
   Run: `grep -rl '{{' .ai CLAUDE.md 2>/dev/null | head` to see what's unfilled.
2. If `$ARGUMENTS` is given, use it as the initial project description; otherwise ask for one.

## Step 2 — Interview (ask in these rounds; 3–6 questions per round, confirm as you go)

Gather values for the whole **variability matrix**. Do not assume — ask. Where the user is unsure,
propose a sensible default and mark it.

- **Identity & domain** → `{{PROJECT_NAME}}`, `{{PROJECT_TAGLINE}}`, `{{PROJECT_TYPE}}`, `{{PROJECT_PURPOSE}}`, `{{TARGET_USERS}}`; the problem it solves, core user journeys, key modules.
- **Repo topology** → `{{REPO_TOPOLOGY}}` (monorepo vs single), which sub-projects exist and their dirs (`{{BACKEND_DIR}}`, `{{FRONTEND_DIR}}`, `{{SOURCE_DIR}}`, `{{IAC_DIR}}`), and the `{{SCOPES}}` model. If single-project, tell the user the `backend/` + `frontend/` scope split collapses to one scope.
- **Tech stack & languages** → `{{PRIMARY_LANGUAGE}}`, `{{BACKEND_LANGUAGE}}`/`{{BACKEND_FRAMEWORK}}`/`{{BACKEND_RUNTIME}}`, `{{FRONTEND_LANGUAGE}}`/`{{FRONTEND_FRAMEWORK}}`, `{{DATABASE}}`, `{{ORM}}`, `{{CLOUD_PROVIDER}}`, `{{AUTH_PROVIDER}}`, `{{PACKAGE_MANAGER}}`, `{{IAC_TOOL}}`, `{{AI_STACK}}` (or "none").
- **Commands** → `{{INSTALL_CMD}}`, `{{DEV_CMD}}`, `{{BUILD_CMD}}`, `{{TEST_CMD}}`, `{{LINT_CMD}}`, `{{TYPECHECK_CMD}}`, `{{MIGRATE_CMD}}`.
- **Conventions & principles** → `{{LAYERING_PATTERN}}`, `{{VALIDATION_LIB}}`, `{{RESPONSE_ENVELOPE}}`, `{{DATA_ACCESS_LAYER}}`, `{{ROUTING_PATTERN}}`; any project-specific rules to record in `.ai/standards/project/**`.
- **Version control** → `{{VCS_PROVIDER}}` (GitHub/GitLab/Bitbucket), `{{VCS_CLI}}` (gh/glab/git), `{{PR_TERM}}` (pull/merge request), `{{DEFAULT_BRANCH}}`, `{{PROTECTED_BRANCHES}}`, `{{DEPLOY_STAGES}}`, `{{BRANCH_PREFIXES}}`, `{{COMMIT_CONVENTION}}`, `{{TICKET_PREFIX}}` (tracker issue-key prefix, e.g. `PROJ` for `PROJ-1234` — ask whether commits reference tickets at all).
- **Security** → `{{AUTH_MECHANISM}}`, and whether multi-tenant isolation applies (`{{TENANT_ISOLATION_RULE}}`, tenant key).
- **Design system** (any UI) → component library, styling system, palette/token source file. Ask whether the UI is a separate SPA, server-rendered by the backend, or both (mid-migration) — the `design/` subtree covers whichever exist, and which scope loads it follows from that. Only if there is no UI at all, tell the user you'll delete the `.ai/standards/project/frontend/design/` subtree.
- **Risk profile** → whether the codebase handles regulated/sensitive data or has thin safety nets; fill the `[FILL IN]` risk blocks in `.ai/workflows/{bug-fixing,hotfix-process}.md`, or delete them.
- **Branding** → `{{COMPANY_NAME}}`, `{{LOGO_PATH}}`, `{{PRIMARY_COLOR}}`, `{{FOOTER_TEXT}}` (see `.ai/config/branding.md`).

## Step 3 — Fill the skeletons

Once values are confirmed:

1. Substitute every `{{TOKEN}}` with its value across the template:
   - `.ai/config/**`, `.ai/context/**`, `.ai/standards/project/**`, `.ai/config/branding.md`, `CLAUDE.md`.
   - Prefer editing files directly. A scripted replace is fine, but never touch reference-only trees:
     the per-stack subfolders below, `.ai/standards/universal/vcs/`, and an `examples/` directory if
     this repo happens to have one (older template layouts shipped a worked example there).
   - **Stack reference library:** the per-stack files under `.ai/standards/project/**/<stack>/` (e.g.
     `backend/node/`, `frontend/react/`) and `.ai/standards/universal/vcs/*.md` are **reference-only** —
     the system reads only the top-level template files. When filling
     `standards/project/<scope>/tech-specific.md` (and `frontend/design/*`, `universal/git-workflow.md`),
     start from the reference matching the chosen stack if one exists; leave the `<stack>/` subfolders
     and `vcs/` profiles as-is (don't treat them as skeletons to fill).
2. Replace each `> [FILL IN: ...]` block with the user's content. If a section genuinely doesn't apply
   (e.g. no frontend, no AI stack), delete that section/file and note it.
3. Set the scope model in `.ai/config/current-scope.md` (usually leave as `auto`).

## Step 4 — Write behavioral config

Write `.claude/hooks/hooks.env` from the answers:
- `PROTECTED_BRANCHES`, `WORK_BRANCH_PREFIXES`, `VCS_CLI`, `PR_TERM`
- `DEPLOY_CMD`, `PROD_STAGE` (if there's a deploy step)
- `PACKAGE_DIRS`, `BACKEND_DIR`, `FRONTEND_DIR`
- `TYPECHECK_CMD`, `LINT_CMD`
- `MIGRATIONS_GLOB` + `MIGRATIONS_REGEN_CMD` (if generated migrations exist), `SENSITIVE_CONFIG_GLOBS`
- Turn on `TENANT_ISOLATION_CHECK`/`FRONTEND_ENV_CHECK`/`DESIGN_TOKEN_CHECK` only if the user opted in, with their supporting values.

## Step 5 — Finish

1. Run `grep -rn '{{' .ai CLAUDE.md .claude/hooks/hooks.env | grep -vE 'CUSTOMIZATION.md|agents/harness-|workflows/harness-improvement|templates/artifact-header|standards/project/[a-z]+/(dotnet|node|react|angular)/|standards/universal/vcs/|examples/'` and resolve or report any leftover tokens. (`.ai/CUSTOMIZATION.md` documents token names, and the per-stack reference files under `standards/project/**/<stack>/` plus `standards/universal/vcs/` are reference-only — don't treat those as unfilled.)
2. Ask whether to delete the reference-only trees now that the stack is chosen — the unused per-stack
   folders under `.ai/standards/project/**/<stack>/`, the unused `.ai/standards/universal/vcs/*`
   profiles, and an `examples/` directory if this repo has one. Delete only what they confirm.
3. Append a one-line entry to `.ai/memory/decisions.md`: `YYYY-MM-DD | Initialized agent system for {{PROJECT_NAME}} | via /init-project | initializer`.
4. Summarize what was filled and suggest the first real command (e.g. `/ba <feature>` or `/agents:architect`).

Project description: $ARGUMENTS
