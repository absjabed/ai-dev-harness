# Git Workflow (Universal)

> This file is provider-agnostic. It uses `{{VCS_PROVIDER}}` / `{{PR_TERM}}` tokens so it reads
> correctly whether your change request is a GitHub/Bitbucket **pull request** or a GitLab
> **merge request**. Set these in `.ai/config/project-config.md` (or via `/init-project`). The branch
> and commit conventions below are sensible defaults — edit them if your team differs.

## Branch naming

Work branches use a `<prefix>/<short-description>` shape. Default prefixes:

- `feature/<short-description>`
- `fix/<short-description>`
- `hotfix/<short-description>`
- `chore/<short-description>`

> [FILL IN: adjust prefixes if your team uses different ones — keep them in sync with
> `WORK_BRANCH_PREFIXES` in `.claude/hooks/hooks.env`.]

## Commit format — {{COMMIT_CONVENTION}}

Default: **Conventional Commits** — `<type>: <subject>` where type is one of:
`feat` · `fix` · `docs` · `test` · `refactor` · `chore` · `perf`

Rules:
- Present tense, **imperative mood** ("add", not "added"/"adds").
- Subject line under **72 characters**; no trailing period.
- One **logical change** per commit.
- Body (optional) explains *why*, wrapped at ~72 cols.

## Change requests ({{PR_TERM}}s on {{VCS_PROVIDER}})

- Every change reaches a protected branch through a {{PR_TERM}} — never a direct push.
  (Protected branches are enforced by `.claude/hooks/git-guard.sh` via `hooks.env`.)
- Description must include: **what** changed, **why**, and **how to test it** (see
  `.ai/templates/pr-description.md`).
- Keep each {{PR_TERM}} focused and reviewable.

## Never commit

- Secrets, credentials, or `.env` files (commit `.env.example` only).
- Generated artifacts or dependency directories (`node_modules`, `venv`, `target`, `dist`, …).
- Commented-out code or debug output.

## Integration

- Rebase work branches onto the base branch before merge — prefer a clean history over
  merge commits (adjust if your team prefers merge commits or squash).
- Resolve conflicts locally and re-run tests before completing the merge.
