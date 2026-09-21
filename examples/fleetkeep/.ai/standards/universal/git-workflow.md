# Git Workflow (Universal)

> This file is provider-agnostic. It uses `GitHub` / `pull request` tokens so it reads
> correctly whether your change request is a GitHub/Bitbucket **pull request** or a GitLab
> **merge request**. Set these in `.ai/config/project-config.md` (or via `/init-project`). The branch
> and commit conventions below are sensible defaults — edit them if your team differs.

## Branch naming

Work branches use a `<prefix>/<short-description>` shape. Default prefixes:

- `feature/<short-description>`
- `fix/<short-description>`
- `hotfix/<short-description>`
- `chore/<short-description>`

These four are exactly `WORK_BRANCH_PREFIXES="feature fix chore hotfix"` in
`.claude/hooks/hooks.env`; changing one means changing both. Branch names carry the ticket:
`feature/FK-1234-inspection-reschedule`.

## Commit format — Conventional Commits

Default: **Conventional Commits** — `<type>: <subject>` where type is one of:
`feat` · `fix` · `docs` · `test` · `refactor` · `chore` · `perf`

Rules:
- Present tense, **imperative mood** ("add", not "added"/"adds").
- Subject line under **72 characters**; no trailing period.
- One **logical change** per commit.
- Body (optional) explains *why*, wrapped at ~72 cols.

## Change requests (pull requests on GitHub)

- Every change reaches a protected branch through a pull request — never a direct push.
  (Protected branches are enforced by `.claude/hooks/git-guard.sh` via `hooks.env`.)
- Description must include: **what** changed, **why**, and **how to test it** (see
  `.ai/templates/pr-description.md`).
- Keep each pull request focused and reviewable.

## Never commit

- Secrets, credentials, or `.env` files (commit `.env.example` only).
- Generated artifacts or dependency directories (`node_modules`, `venv`, `target`, `dist`, …).
- Commented-out code or debug output.

## Integration

- Rebase work branches onto the base branch before merge — prefer a clean history over
  merge commits (adjust if your team prefers merge commits or squash).
- Resolve conflicts locally and re-run tests before completing the merge.
