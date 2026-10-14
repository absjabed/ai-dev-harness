# Customization Guide

> This guide lives at `.ai/CUSTOMIZATION.md` (referenced from the root `README.md`).

This template ships a full Claude Code agent system with all project-specific details replaced by
placeholders. There are two ways to fill them in:

1. **Automated:** run `/init-project` in Claude Code. It interviews you about every axis below and fills
   in all skeletons, `hooks.env`, and branding. (Recommended for a first setup.)
2. **Manual:** edit the files yourself using this guide. This is useful for tweaks after `/init-project`,
   or if you prefer full control.

## How placeholders work

- **`{{TOKEN}}`:** a single value substituted everywhere it appears (e.g. `{{PROJECT_NAME}}`,
  `{{TEST_CMD}}`). Replace it with your value.
- **`> [FILL IN: guidance]`:** a prose block you must write yourself (descriptions, rules, journeys).
  Replace the whole blockquote with your content, or delete the section if it doesn't apply.
- Files starting with `<!-- TEMPLATE FILE ... -->` are skeletons meant to be filled. Files without it
  are portable: reuse them as-is, and edit one only if you disagree with a default.

When you're done, this should return nothing:

```bash
grep -rnE '\{\{[A-Z][A-Z0-9_]*\}\}' .ai .claude CLAUDE.md | grep -vE 'CUSTOMIZATION.md|agents/harness-|workflows/harness-improvement|commands/init-project.md|standards/project/[a-z]+/(dotnet|node|react|angular)/|standards/universal/vcs/|examples/'
```

It scans `.claude/` as well as `.ai/`, because commands and sub-agents contain tokens too, in addition
to config and context. Some files are excluded on purpose. This guide, `init-project.md` and the
harness-maintenance files document token *names* such as `{{PROJECT_NAME}}`. The per-stack folders and
VCS provider profiles are reference-only (see [the stack reference
library](#the-stack-reference-library)).

---

## The variability axes

This section lists everything that changes from project to project and where to change it.

### 1. Identity & domain
- **Files:** `.ai/config/project-config.md`, `.ai/context/project-overview.md`, `CLAUDE.md`
- **Tokens:** `{{PROJECT_NAME}}` `{{PROJECT_TAGLINE}}` `{{PROJECT_TYPE}}` `{{PROJECT_PURPOSE}}` `{{TARGET_USERS}}`
- Describe what the product does, its users, core journeys, and key modules.

### 2. Repo topology & scope model
- **Files:** `.ai/config/*` (+ `backend/`, `frontend/` variants), `.ai/config/current-scope.md`, `.claude/hooks/hooks.env` (`PACKAGE_DIRS`)
- **Tokens:** `{{REPO_TOPOLOGY}}` `{{SCOPES}}` `{{BACKEND_DIR}}` `{{FRONTEND_DIR}}` `{{SOURCE_DIR}}` `{{IAC_DIR}}`
- For a monorepo with a backend and a frontend, keep both scope trees. For a single project, delete the
  `backend/` and `frontend/` subfolders under `config/`, `context/` and `standards/project/`, and use
  only the top-level files. Scope auto-detection then collapses to one scope.

### 3. Tech stack & languages
- **Files:** `.ai/config/project-config.md`, `.ai/standards/project/**/tech-specific.md`
- **Tokens:** `{{PRIMARY_LANGUAGE}}` `{{BACKEND_LANGUAGE}}` `{{BACKEND_FRAMEWORK}}` `{{BACKEND_RUNTIME}}` `{{FRONTEND_LANGUAGE}}` `{{FRONTEND_FRAMEWORK}}` `{{DATABASE}}` `{{ORM}}` `{{SECONDARY_DATASTORE}}` `{{CLOUD_PROVIDER}}` `{{AUTH_PROVIDER}}` `{{PACKAGE_MANAGER}}` `{{IAC_TOOL}}` `{{AI_STACK}}`
- Write your stack's concrete rules in `standards/project/**/tech-specific.md` (the universal ones stay portable).
- **Starting point:** the per-stack reference library (see [The stack reference library](#the-stack-reference-library))
  gives you a worked example for common stacks. Copy the rules that fit into the template file.

### 4. Commands
- **Files:** `.ai/config/project-config.md`, `CLAUDE.md`, `.claude/hooks/hooks.env`
- **Tokens:** `{{INSTALL_CMD}}` `{{DEV_CMD}}` `{{BUILD_CMD}}` `{{TEST_CMD}}` `{{LINT_CMD}}` `{{TYPECHECK_CMD}}` `{{MIGRATE_CMD}}`
- The hooks run `TYPECHECK_CMD`/`LINT_CMD` after edits. Set them in `hooks.env` to enable this.

### 5. Conventions & principles
- **Files:** `.ai/standards/project/**`, `CLAUDE.md`; universal principles in `.ai/standards/universal/*` (portable);
  area-specific rules in `.claude/rules/**/*.md`
- **Tokens:** `{{LAYERING_PATTERN}}` `{{VALIDATION_LIB}}` `{{RESPONSE_ENVELOPE}}` `{{DATA_ACCESS_LAYER}}` `{{ROUTING_PATTERN}}`
- **Path-scoped rules:** knowledge that only matters in one area of the code (a legacy screen, a
  module with its own traps) goes in `.claude/rules/<area>.md` with `paths:` frontmatter. Claude Code
  loads such a rule only when a matching file is read or edited. A rule without `paths:` loads in every
  session, so keep project-wide rules in `tech-specific.md` instead. Start from
  `.claude/rules/_example-area.md`; `/utils:learn` offers this route for area-specific lessons.

### 6. Version control (provider-agnostic)
- **Files:** `.ai/standards/universal/git-workflow.md`, `.ai/templates/pr-description.md`, `.claude/hooks/hooks.env`, `.ai/workflows/{bug-fixing,hotfix-process,release-process,feature-development}.md`, `.claude/commands/workflows/*`
- **Tokens:** `{{VCS_PROVIDER}}` `{{VCS_CLI}}` `{{PR_TERM}}` `{{DEFAULT_BRANCH}}` `{{PROTECTED_BRANCHES}}` `{{DEPLOY_STAGES}}` `{{BRANCH_PREFIXES}}` `{{COMMIT_CONVENTION}}` `{{TICKET_PREFIX}}`
- `{{TICKET_PREFIX}}` is your tracker's issue-key prefix (e.g. `PROJ` for `PROJ-1234`), used in commit
  and branch-name examples. If the project doesn't reference tickets in commits, delete those clauses.
- The setup works for GitHub (PR / `gh`), GitLab (MR / `glab`), or Bitbucket. `hooks.env` enforces
  protected branches and deploy guards through `git-guard.sh`.
- **Starting point:** the provider profiles in `.ai/standards/universal/vcs/` (`github.md` is filled;
  `bitbucket.md` and `gitlab.md` are stubs) list the values to set for each provider.

### 7. Security
- **Files:** `.ai/standards/universal/security-baseline.md` (project note), `.claude/hooks/hooks.env`
- **Tokens:** `{{AUTH_MECHANISM}}` `{{TENANT_ISOLATION_RULE}}`
- For multi-tenant apps, turn on `TENANT_ISOLATION_CHECK` and set `TENANT_KEY` in `hooks.env`.

### 8. Design system (UI)
- **Files:** `.ai/standards/project/frontend/design/{palette,design-tokens,component-specs,README}.md`
- **Tokens:** `{{COMPONENT_LIBRARY}}` `{{STYLING_SYSTEM}}` `{{PRIMARY_COLOR}}`, plus per-cell tokens
  (`{{COLOR_*}}`, `{{RADIUS_*}}`, `{{BP_*}}`, `{{FONT_FAMILY_SANS}}`, …) synced from your theme file.
- This subtree governs whatever UI the project has. It still applies when the UI is server-rendered
  rather than a separate SPA: keep it, and load it from the scope that owns the server-rendered views.
  If two UI stacks coexist mid-migration, describe both in `design/README.md` and say which one new
  work belongs to.
- If the project has no UI to design at all (a headless or API-only project), delete the whole
  `.ai/standards/project/frontend/design/` subtree.

### 9. Branding of generated artifacts
- **Files:** `.ai/config/branding.md`, `.ai/branding/` (logo), `.ai/templates/artifact-header.md`
- **Tokens:** `{{COMPANY_NAME}}` `{{LOGO_PATH}}` `{{PRIMARY_COLOR}}` `{{FOOTER_TEXT}}`
- Every generated `.md` artifact (specs, stories, test specs, reports) starts with your branded header.
  Put your logo in `.ai/branding/` and point `LOGO_PATH` at it.
- **Deliberate exceptions:** the internal files `.ai/features/**/STATE.md` (workflow state) and
  `.ai/features/**/deploy-notes.md` (deploy input) are unbranded. So is the deployment guide
  (axis 13), which has its own title. Its Word copy uses `COMPANY_NAME` and `PRIMARY_COLOR`.

### 10. Hook behavior toggles
- **File:** `.claude/hooks/hooks.env` (the single source for all hook behavior)
- If a value is empty or `*_CHECK="off"`, that check is skipped. An un-customized template is inert-safe.

### 11. Agent model & reasoning effort
- **Files:** frontmatter of `.claude/agents/*` and `.claude/commands/**`
- Set `model:` and effort per agent if you want cheaper agents for mechanical work and stronger models
  for review and architecture.

### 12. Integrations (MCP)
- **Files:** `.mcp.json` (repo root) + `allowed-tools:` grants in `.claude/commands/**`
- The template ships Atlassian's remote MCP server (Jira/Confluence via OAuth; the file holds no
  secrets), the Figma bridge, and Playwright MCP for runtime UI checks (axis 14). If your tracker
  differs, swap or remove the server entry. It points at Atlassian's v2 endpoint
  (`https://mcp.atlassian.com/v2/mcp`), which lists only its primary tools directly. Other tools go
  through its `discover` and `execute` tools: call `discover` first and use the exact parameter names it
  returns, because a misnamed parameter is dropped silently. The `mcp__atlassian` grant covers both.
  v2 is a separate OAuth resource, so a sign-in made against v1 must be redone with `/mcp`. Grant its
  tools (`mcp__<server>`) only to the commands that
  need them, and keep integration steps optional so everything works with no server connected. The
  binding rules are invariants 9 to 13 in `.ai/workflows/harness-improvement.md`. Change integrations
  through `/harness:improve`.

### 13. Release deliverables
- **Files:** `.ai/config/project-config.md` → *Release deliverables*; templates
  `.ai/templates/{deploy-notes,deployment-guide,release-guides-index}.md`; converter
  `.claude/scripts/md-to-docx.py`
- Every feature, bugfix and hotfix writes `.ai/features/<slug>/deploy-notes.md`, which records what the
  change needs at deploy time. The notes are stamped with the fix version that `/ba` records in each
  requirement spec. The release path selects notes by fix version and folds them into its internal
  artifacts.
- **Deployment guide** (`on` / `off`): when on, `/workflows:release` also assembles a human-facing
  guide at `docs/release/<version>/deployment-guide-<version>.md` for whoever deploys the product,
  and keeps an index in `docs/release/README.md`. Set the audience, deployable units and rollout
  order in the same config section. They shape the guide's sections.
- **Word copy** (`on` / `off`): a `.docx` generated from the guide by
  `python .claude/scripts/md-to-docx.py <guide>.md --org "<company>" --color "<#primary>"`
  (Python 3, `python-docx` and `markdown-it-py`).
  The Markdown stays the single source of truth, and the `.docx` is never hand-edited. For a different
  deliverable (PDF, wiki page), swap only the converter and the regenerate step.
- If you don't track releases by version, leave the guide off. Deploy notes still record each change's
  deploy impact, with the fix version `unknown — to be confirmed`.

### 14. Runtime verification (API / UI / DB checks)
- **Files:** `.ai/config/project-config.md` → *Test environments*; playbook
  `.ai/workflows/runtime-verification.md`; template `.ai/templates/e2e-report.md`; `.mcp.json`
  (`playwright`); `E2E_FORBIDDEN_HOSTS` in `.claude/hooks/hooks.env` (enforced by `e2e-guard.sh`)
- After review and the security scan, `/workflows:feature`, `/workflows:bugfix` and
  `/workflows:hotfix` (smoke only) propose API, UI and DB checks based on the change, confirm the plan
  with you once, and run the checks against the test environment. `/workflows:verify` does the same
  for ad-hoc work. A FAIL, or a planned check that did not run, blocks the commit unless you accept it.
- **UI driver:** the default is Claude in Chrome. Each developer needs the browser extension, a
  claude.ai login, and Claude Code started with `claude --chrome` (or `/chrome` → *Enabled by
  default*). A project file cannot switch it on. Playwright MCP (shipped in `.mcp.json`, fetched by
  `npx`) is the fallback; set the UI driver to `playwright` to make it the default. Pin
  `@playwright/mcp` to a version if your policy requires it.
- **Database checks** are opt-in and engine-specific, so no server ships. Add a read-only database
  MCP server for your engine to `.mcp.json`. Connect it as a **SELECT-only** user, to a local or test
  database only, with credentials from an environment variable and never in the file. Then name it in
  *Test environments* and grant `mcp__<server>` in the `allowed-tools` of the four commands above.
  Without one, DB checks are reported NOT RUN and API reads stand in.
- **Never production:** list production host substrings in `E2E_FORBIDDEN_HOSTS`. `e2e-guard.sh`
  hard-blocks HTTP clients in Bash/PowerShell and browser-tool navigation to them. It is global on
  purpose: the agent never calls or browses production for any reason, so a human or CI does the
  post-deploy production checks. It cannot see a test runner's own config, so keep production URLs
  out of test config too.
- **Credentials:** API tests take a test token from a token *command* run inline per request, or
  from an environment variable exported **before** starting Claude Code (an `export` inside the
  session does not persist between tool calls). Screenshots stay local: add
  `.ai/features/**/e2e-screenshots/` to the project's `.gitignore`.

---

## The stack reference library

Next to each template tech-specific file, the repo ships per-stack reference files that give SMEs a
worked starting point:

```
.ai/standards/project/backend/
  tech-specific.md          ← TEMPLATE  (the system reads ONLY this)
  node/tech-specific.md     ← filled reference (Node/serverless)
  dotnet/tech-specific.md   ← empty stub to fill

.ai/standards/project/frontend/
  tech-specific.md          ← TEMPLATE
  react/  (tech-specific.md + design/*)   ← filled reference
  angular/ (tech-specific.md + design/…)  ← empty stub

.ai/standards/universal/vcs/
  github.md                 ← filled provider profile
  bitbucket.md · gitlab.md  ← empty stubs
```

**How to use them** (the first point is the main rule):

- **The agent system reads only the template files** (`standards/project/backend/tech-specific.md`,
  `standards/project/frontend/tech-specific.md` + `frontend/design/*`, and
  `standards/universal/git-workflow.md`). Commands never load the per-stack subfolders.
- The per-stack files are reference-only. An SME opens the file that matches their stack and copies
  the rules that fit into the project's template file.
- Filled references (`node`, `react`, `github`) are worked examples. Adapt their paths and values to
  your project.
- Empty stubs (`dotnet`, `angular`, `bitbucket`, `gitlab`) are skeletons. Fill the ones that match
  your stack, then copy them into the template file. Ignore the stacks you don't use, or delete them.
- To add a new stack, create a sibling folder or file with the same shape (e.g.
  `backend/java/tech-specific.md`).

> In short, the system uses the template files, and the stack files are a reference the SME copies from.

---

## What you fill vs what's portable

| Fill in (skeletons) | Portable (reuse as-is) | Reference-only (copy from) |
|---|---|---|
| `.ai/config/**`, `.ai/context/**` | `.ai/standards/universal/*` | `.ai/standards/project/**/<stack>/` |
| `.ai/standards/project/**/tech-specific.md` + `frontend/design/*` | `.ai/workflows/*`, `.ai/templates/*` | `.ai/standards/universal/vcs/*` |
| `.ai/config/branding.md`, `.ai/branding/` | `.ai/agents/*`, `.ai/memory/*` (decisions, learnings, design-taste) | |
| `CLAUDE.md`, `.claude/hooks/hooks.env`, `.claude/rules/*` (as you add them) | `.claude/commands/*`, `.claude/agents/*`, `.claude/settings.json`, `.claude/scripts/*` | |

## A worked reference

`examples/fleetkeep/` is a complete, filled-in version of this template for a sample project called
FleetKeep, a multi-tenant compliance and maintenance platform for commercial vehicle fleets. It has
an ASP.NET Core 8 API, a React 18 + Vite 5 SPA on Mantine, an Azure Functions worker, and Bicep
infrastructure on Azure, with GitHub as the VCS. Read it side by side with the skeletons to see what
a finished setup looks like: every token substituted, every `[FILL IN]` answered, `hooks.env`
configured with the tenant-isolation, design-token and TDD checks switched on, and the reference-only
stack folders deleted.

`/init-project` offers to delete `examples/` once your own project is configured.

Your team may also have kept a second worked reference: a snapshot of this harness fully configured
on a real project (filled configs and context, feature artifacts, accumulated memory logs). Ask
whoever handed you the harness where that snapshot lives. It is kept outside the template on
purpose, so it never gets copied into a new repo.
