---
description: Prepare a release — security gate, full release artifacts, changelog, version bump
allowed-tools: Read, Write, Edit, Bash, Task, mcp__atlassian
---
@.ai/workflows/release-process.md

**Scope determination (do this first, before any other action):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise, analyze "$ARGUMENTS" to determine scope:
   - backend-only release → backend
   - frontend-only release → frontend
   - version number alone or no qualifier → fullstack
3. Load only the files for the determined scope using the Read tool:
   - **backend**: `.ai/config/backend/project-config.md`
   - **frontend**: `.ai/config/frontend/project-config.md`
   - **fullstack**: both project-config files

Release version: $ARGUMENTS

## Step 1 — Security gate & release artifacts (parallel)

Spawn both of the following Task agents **concurrently** and wait for both to complete:

**security-scanner** — on the full diff vs the last release tag:

> "Run a security scan on `git diff $(git describe --tags --abbrev=0)..HEAD`. Scope: [determined scope]. Apply the full security-agent checklist including a dependency audit (NuGet (.NET) and npm (web)). Output a security report in chat AND save it to `.ai/releases/$ARGUMENTS/security-report.md`."

**release-manager** — prepare release artifacts:

> "Prepare release artifacts for version $ARGUMENTS. Scope: [determined scope]. Follow the release-agent methodology: enumerate commits since the last tag, check EF Core 8 migrations, generate release notes, migration plan, rollback plan, and deployment checklist. Write all four files to `.ai/releases/$ARGUMENTS/`."

Once both agents return, evaluate the security results:
- If the security scan returns any **CRITICAL** findings: **STOP** — show the user the findings and do not proceed until they are resolved.
- HIGH findings should be noted and the user asked whether to proceed.

The release artifacts are now available at `.ai/releases/$ARGUMENTS/`.

## Step 2 — Run quality gates

For each sub-project that changed, run its quality gates (from the loaded project-config):
- `dotnet format --verify-no-changes`
- `dotnet test`
- `dotnet build -c Release`

Report any failures.

## Step 3 — STOP for confirmation

Show the user:
- Security scan verdict (pass/fail, finding counts) — and the saved report at `.ai/releases/$ARGUMENTS/security-report.md`
- Paths to generated release artifacts under `.ai/releases/$ARGUMENTS/`
- Quality gate results (lint/test/build)
- Any CRITICAL or HIGH security findings

Get explicit confirmation before proceeding to step 4.

## Step 4 — Finalize

On user confirmation:
1. Bump the version in each sub-project's manifest — e.g. `src/Api` (semver: fix → patch, feat → minor, BREAKING → major)
2. Bump the version in the other sub-projects' manifests — e.g. `src/Web` — to match
3. Update `CHANGELOG.md` with the release notes content (Keep a Changelog format)
4. Commit: `chore(release): bump version to $ARGUMENTS`
5. Tag: `git tag $ARGUMENTS`
6. **Issue-tracker update (optional)** — only if an issue-tracker MCP server is connected
   (see `.mcp.json`): collect the issue keys referenced in this release's commit messages,
   then **STOP** — show the user the list of issues, the transition to apply (e.g. → Done),
   and the release-note comment to attach. Apply only on explicit confirmation. Skip this
   step silently when no server is connected.

Do not push or deploy — that is the DevOps agent's responsibility.
