<!-- STACK REFERENCE (stub) — GitLab provider profile. Reference only: the system does NOT read this
     file. Branch/commit conventions live in the portable TEMPLATE
     .ai/standards/universal/git-workflow.md. SME: fill the values below (see ./github.md for shape). -->

# VCS Provider Profile — GitLab (stub)

_Not yet filled. See `./github.md` for the shape, then record your GitLab choices._

## Values to set (hooks.env vars / tokens)

| Setting | GitLab value |
|---------|--------------|
| VCS_PROVIDER | GitLab |
| VCS_CLI | `glab` |
| PR_TERM | merge request (MR) |
| DEFAULT_BRANCH | _e.g. `main`_ |
| CI system | GitLab CI (`.gitlab-ci.yml`) |

## Merge requests
_e.g. `glab mr create`, required approvals, merge-when-pipeline-succeeds; note GitLab uses **MR**
terminology throughout — set PR_TERM accordingly._

## CI
_e.g. `.gitlab-ci.yml` stages; wire lint/type-check/test as required pipeline jobs._

_For branch naming, commit format, and the "never commit" rules, see the portable
`.ai/standards/universal/git-workflow.md`._
