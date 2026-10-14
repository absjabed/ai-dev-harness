# Getting Started

This guide takes the template from a clone to a working AI development workflow in a project, with its gates and guardrails in place.
Budget 30 to 60 minutes for the first project. Most of that time goes into answering `/init-project`'s interview well.

---

## 0. What you are adopting

The harness is two folders and a contract:

- `.ai/` is the Knowledge Layer. It contains only Markdown, and nothing in it executes. It holds the
  agent personas, the workflow playbooks, the engineering standards, the output templates, and the
  project's own config/context.
- `.claude/` is the Execution Layer: the slash commands you type, the sub-agents they spawn, and
  nine hooks that Claude Code runs automatically around your edits and commands.

The contract is that agents read `.ai/`, Claude Code runs `.claude/`, and everything project-specific
lives in filled-in skeletons instead of in prompts. That is why the same harness behaves correctly
on a .NET monorepo and on a Python service.

### Why use it

AI can already write the code. Left unsupervised, it does badly at the work around the code: knowing
this project's conventions, proving that the change works, and stopping before something
irreversible. Each mechanism below addresses a specific failure mode.

| Without a harness | What the harness does |
|---|---|
| You re-explain the stack, conventions and domain every session, and the answers drift | The filled `.ai/config/` and `.ai/context/` load automatically, scoped to the task. The project's rules are written in a file instead of remembered from an old prompt |
| Output quality depends on how well you phrased today's prompt | Personas and playbooks fix the method, so `/agents:review` applies the same severity vocabulary on a Friday as on a Monday |
| AI-written code lands after a glance, because reviewing it is slower than accepting it | The reviewer and security scanner run in parallel, in separate contexts, and report problems without fixing them. CRITICAL findings block the commit, so the gate is not optional and you cannot forget it |
| The code passed review and tests, but nobody called the API or clicked through the screen | Runtime verification runs after review and security: real API calls, a browser run of the journeys, and read-only DB checks against the test environment. Failed or skipped planned checks block the commit until you accept them |
| "Tests pass", but nobody checks whether tests exist for that scope | Verification is scope-aware: real tests where a runner exists, a clean build plus a documented manual reproduction where none does, and the report states which happened |
| One bad command (a force push, a hard reset, a deploy to prod) undoes a day | Hooks hard-block these at the tool call, regardless of what the model intended |
| The reason for a decision lives in a Slack thread that's now gone | Append-only `decisions`, `learnings` and `design-taste` logs keep it. The designer reads rejected patterns before proposing anything, so a rejected pattern stays rejected |
| A long session loses the thread, and the next one starts cold | `STATE.md` records phase, tasks and decisions. Re-running resumes from it and re-verifies each "done" phase's artifact before trusting it |
| Parallel work on one feature collides in the working tree | The epic path gives each sub-feature its own git worktree, merged in dependency order |
| Every repo grows its own private way of working with AI | Every project gets the same harness, commands and gates, so someone joining learns it once |

The harness has a cost in process overhead. The full path (`/ba` → `/qa` → `/workflows:feature`, with
five STOP gates) is built for work that deserves a spec. For a typo or a one-line fix the overhead is
real and not worth paying, so use `/agents:dev` or `/workflows:bugfix` instead. The harness also can't
make a codebase testable, and it won't catch a bad decision you approve at a gate. It prevents the
failures that come from forgetting a step, but failures of judgment still get through.

---

## 1. Prerequisites

| Need | Why it matters |
|---|---|
| **Claude Code** (CLI, desktop app, or IDE extension) opened at the repo root | Commands, sub-agents and hooks are discovered per repo from `.claude/` |
| **Bash** on `PATH` (Git Bash or WSL on Windows) | All nine hooks are `.sh` scripts. Without bash they fail quietly, and every guardrail is off even though it looks installed |
| **git** | Branch guards, changelog/standup commands, and the epic path's worktrees |
| *(optional)* an MCP server | `.mcp.json` ships Atlassian (Jira/Confluence, OAuth), a Figma bridge and Playwright (fetched by `npx`). Authenticate once with `/mcp`. Everything still works, with reduced function, when a server is not connected |
| *(for UI runtime checks)* **Claude in Chrome** | The default UI driver. Each developer starts Claude Code with `claude --chrome` (or `/chrome` → *Enabled by default*), installs the extension, and signs in with `/login`. Without it, Playwright is used |

To check that bash is really available:

```bash
bash -c 'echo bash-ok' && git --version
```

---

## 2. Copy the harness into your project

From a clone of this repo, copy these into your project's repo root:

```
.ai/  .claude/  .mcp.json  CLAUDE.md  AGENTS.md  COMMANDS.md  README.md
```

`.claude/HARNESS_VERSION` comes along with `.claude/`. It records which template release you copied
(it matches a `v<version>` tag here), and `/init-project` notes it in `.ai/memory/decisions.md`.
Leave it as it is. Later, `git log v<version>..` in this repo lists everything you don't have yet.

You can also bring `examples/fleetkeep/` along while you configure. It is a fully worked version of
every file you are about to fill in, and `/init-project` offers to delete it at the end.

**Do not copy this repo's `.gitignore`.** It is written for the template itself. Your project must
have these lines:

```gitignore
.worktrees/
.ai/features/**/e2e-screenshots/
```

Do not ignore `.ai/features/`. The epic path commits planning artifacts onto the epic branch, and git
worktrees only see committed files. Do not ignore `.claude/agent-memory/` either: the reviewer,
security scanner, critic and harness engineer write what they learn there, and committing it shares
that with the team. `.claude/settings.local.json` is per-developer, so do ignore that one.

---

## 3. Fill the template

```
/init-project
```

It interviews you in rounds and then writes every skeleton. Have answers ready for:

| Round | What it asks |
|---|---|
| Identity & domain | Product name, tagline, purpose, target users, core journeys |
| Repo topology | Monorepo or single project; the backend / frontend / infra directories |
| Tech stack | Languages, frameworks, database, ORM, cloud, auth provider, package manager |
| Commands | install / dev / build / test / lint / typecheck / migrate |
| Conventions | Layering pattern, validation library, response envelope, routing pattern |
| Version control | Provider, CLI, PR term, default and protected branches, branch prefixes, commit convention, ticket prefix |
| Security | Auth mechanism; whether multi-tenant isolation applies and what the tenant key is |
| Design system | Component library, styling system, token source file; whether the UI is an SPA, server-rendered, or both |
| Risk profile | Whether the codebase handles regulated data or has thin safety nets |
| Branding | Company name, logo, primary colour, footer for generated documents |
| Test environments | Local/dev API and UI URLs, how to start them, how to get a test token, test accounts, production hosts to forbid, optional read-only DB MCP |
| Release deliverables | Whether someone outside the team deploys (this turns on the deployment guide), its audience, a Word copy, the deployable units and rollout order |

To do it by hand, or to adjust things later, use [`.ai/CUSTOMIZATION.md`](../.ai/CUSTOMIZATION.md). It
maps all 13 variability axes to the exact files and tokens they own.

While you are there, shape the tree to fit the repo:

- Single-project repo → delete the `backend/` and `frontend/` subfolders under `.ai/config/`,
  `.ai/context/` and `.ai/standards/project/`. Scope detection collapses to one scope.
- No UI at all (headless / API-only) → delete `.ai/standards/project/frontend/design/`.
- The per-stack folders (`standards/project/backend/{dotnet,node}`,
  `standards/project/frontend/{react,angular}`) and `standards/universal/vcs/*` are for reference
  only, and agents never read them. Copy what fits into your `tech-specific.md`, then delete the
  stacks you don't use.

---

## 4. Verify

Check that nothing unfilled remains:

```bash
grep -rnE '\{\{[A-Z][A-Z0-9_]*\}\}' .ai .claude CLAUDE.md | grep -vE 'CUSTOMIZATION.md|agents/harness-|workflows/harness-improvement|commands/init-project.md|standards/project/[a-z]+/(dotnet|node|react|angular)/|standards/universal/vcs/|examples/'
```

Empty output means you are done. The search covers `.claude/` as well as `.ai/`, because commands and
sub-agents carry tokens too, and an unfilled one there stays invisible until a command misbehaves.
The exclusions are deliberate. `CUSTOMIZATION.md`, `init-project.md` and the harness-maintenance docs
discuss token names, and the per-stack and VCS files are references you copy from.

Next, check that the guardrails are actually on. `.claude/hooks/hooks.env` is the single config for
all hook behaviour, and it is inert-safe: a blank value or `*_CHECK="off"` skips that check silently.
An un-customised file blocks nothing, even though the hooks look fully installed. At minimum, set:

| Key | Effect if unset |
|---|---|
| `PROTECTED_BRANCHES` | Direct pushes to main/develop are not blocked |
| `TYPECHECK_CMD` / `LINT_CMD` + `PACKAGE_DIRS` | No type-check or lint runs after edits |
| `MIGRATIONS_GLOB` | Generated migrations can be hand-edited without warning |
| `SENSITIVE_CONFIG_GLOBS` | No warning before editing secrets-bearing config |
| `TENANT_ISOLATION_CHECK` + `TENANT_KEY` | No tenant-scoping check on data-access edits |

Smoke-test one hook: on a protected branch, ask Claude to run `git push --force` and confirm it is
refused.

---

## 5. Your first feature

The studios produce the specs, and the workflow consumes them. The workflow will not generate them
for you.

```
/ba  <feature-slug>      # requirement-spec.md + user-stories.md (or epic-breakdown.md for an epic)
/qa  <feature-slug>      # test-specs.md, derived from the above
/workflows:feature <feature-slug>
```

What to expect from `/workflows:feature`:

1. It reads the BA/QA artifacts and stops if any are missing.
2. It writes `STATE.md`, the machine-maintained record of phase, tasks, decisions and next action.
   If you re-run the command later, it resumes from that file, first verifying that each "done"
   phase really produced its artifact.
3. It determines scope (backend / frontend / fullstack) and loads only that scope's context.
4. It writes a technical spec and stops for your approval, asking once whether to enable per-task
   atomic commits.
5. If there is a UI surface, the design gate runs: UX → visual design → an Artifact preview → your
   approval loop.
6. Implementation is delegated to a developer sub-agent with fresh context.
7. Verification follows the scope's gates: real tests where a test runner exists, or a clean build
   plus a documented manual reproduction where none does. It states which one it did.
8. The reviewer and security scanner run in parallel on the diff. CRITICAL findings block the commit.
9. It stops before committing, and again before opening the pull request.

That workflow has five STOP gates, and they are its purpose. The harness is built so that a human
approves the spec, the design, the commit and the PR.

Everything lands under `.ai/features/<slug>/`, and each document carries your branded header.

### Other entry points

| Situation | Command |
|---|---|
| Small change, no formal specs needed | `/agents:dev "<change>"` |
| A bug | `/workflows:bugfix "<symptom>"` |
| Urgent production fix | `/workflows:hotfix "<symptom>"` |
| Prove a change works against the running system | `/workflows:verify "<what changed>"` |
| Cutting a release | `/agents:security` then `/workflows:release <version>` |
| Daily check-in | `/utils:status`, `/utils:standup` |
| Force a scope for the session | `/utils:scope backend` |
| Record a lesson learned | `/utils:learn "<one-liner>"` (area-specific lessons can become a `.claude/rules/` file) |
| A question about the harness itself | `/harness:ask "<question>"` |

---

## 6. Keeping it healthy

- Memory grows with the project. `.ai/memory/decisions.md`, `learnings.md` and `design-taste.md`
  are append-only logs that agents read before acting and write to afterwards. They are what stops
  an assistant from repeating a mistake.
- Change the harness with `/harness:improve` instead of hand-editing prompts. It runs an
  author → critic → revise → recheck loop with an integration audit against the harness's own
  invariants.
- Revisit `hooks.env` when the stack changes. A new test runner makes `TDD_CHECK` satisfiable, and a
  new UI makes the design-token check useful.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Hooks never fire | No bash on `PATH` (common on Windows) | Install Git Bash / WSL; re-test with `bash -c 'echo ok'` |
| Hooks fire but nothing is ever blocked | `hooks.env` still inert | Fill `PROTECTED_BRANCHES`, the command keys, and the `*_CHECK` toggles |
| A workflow says artifacts are missing | The studios haven't run | `/ba <slug>` then `/qa <slug>` first |
| Agents cite the wrong stack | A `tech-specific.md` or `project-config.md` is still a skeleton | Re-run the verify grep from step 4 |
| A command loads too much context | Scope detection guessed wide | `/utils:scope backend` (or `frontend`) for the session |
| Resume picks up in the wrong place | `STATE.md` claims a phase is done but its artifact is missing | The workflow re-runs that phase automatically; delete `STATE.md` to start clean |
| Generated docs have no logo/footer | `.ai/config/branding.md` unfilled | Fill it and drop a logo in `.ai/branding/` |
