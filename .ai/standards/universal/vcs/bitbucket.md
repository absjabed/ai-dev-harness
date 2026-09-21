<!-- STACK REFERENCE (stub) — Bitbucket provider profile. Reference only: the system does NOT read
     this file. Branch/commit conventions live in the portable TEMPLATE
     .ai/standards/universal/git-workflow.md. SME: fill the values below (see ./github.md for shape). -->

# VCS Provider Profile — Bitbucket (stub)

_Not yet filled. See `./github.md` for the shape, then record your Bitbucket choices._

## Values to set (hooks.env vars / tokens)

| Setting | Bitbucket value |
|---------|-----------------|
| VCS_PROVIDER | Bitbucket |
| VCS_CLI | _e.g. none / REST API / a wrapper_ |
| PR_TERM | pull request (PR) |
| DEFAULT_BRANCH | _e.g. `main`_ |
| CI system | Bitbucket Pipelines (`bitbucket-pipelines.yml`) |

## Pull requests
_e.g. required reviewers, merge checks, how the workflow opens a PR (Bitbucket has no first-party
`gh`-style CLI — document your approach: web UI, REST API, or a chosen tool)._

## CI
_e.g. `bitbucket-pipelines.yml` steps; wire lint/type-check/test as merge checks._

_For branch naming, commit format, and the "never commit" rules, see the portable
`.ai/standards/universal/git-workflow.md`._
