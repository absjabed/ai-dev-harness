<!-- STACK REFERENCE — GitHub provider profile. Reference only: the system does NOT read this file.
     The branch/commit conventions live in the portable TEMPLATE at
     .ai/standards/universal/git-workflow.md. This profile records the GitHub-specific choices an SME
     sets in .claude/hooks/hooks.env and git-workflow.md. -->

# VCS Provider Profile — GitHub

The provider-specific values behind the portable `git-workflow.md`. Set these in
`.claude/hooks/hooks.env` and reference them in `git-workflow.md` / `pr-description.md`.

## Values to set (hooks.env vars / tokens)

| Setting | GitHub value |
|---------|--------------|
| VCS_PROVIDER | GitHub |
| VCS_CLI | `gh` |
| PR_TERM | pull request (PR) |
| DEFAULT_BRANCH | `main` |
| CI system | GitHub Actions (`.github/workflows/*.yml`) |

## CLI (`gh`)

- Create a PR: `gh pr create --fill --base <base>` (or with an explicit `--title` / `--body`).
- View / check status: `gh pr view`, `gh pr checks`.
- Requires `gh auth login` once per machine. The workflows call the CLI named in VCS_CLI.

## Pull requests

- Description must include **what** changed, **why**, and **how to test it** (template:
  `.ai/templates/pr-description.md`).
- Enable **branch protection** on `main`: require PR review + green status checks before merge.

## CI

- Workflows live in `.github/workflows/`. Wire lint/type-check/test as required checks so the branch
  protection gate is meaningful.

_For branch naming, commit format, and the "never commit" rules, see the portable
`.ai/standards/universal/git-workflow.md`._
