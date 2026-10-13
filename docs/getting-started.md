# Getting Started

How to take this template from a clone to a working, governed AI development workflow in a project.
Budget 30–60 minutes for the first one, mostly spent answering `/init-project`'s interview well.

---

## 0. What you are adopting

The harness is **two folders and a contract**:

- `.ai/` — the **Knowledge Layer**. Markdown only; nothing here executes. It holds the agent
  personas, the workflow playbooks, the engineering standards, the output templates, and the
  project's own config/context.
- `.claude/` — the **Execution Layer**. The slash commands you type, the sub-agents they spawn, and
  nine hooks that Claude Code runs automatically around your edits and commands.

The contract: **agents read `.ai/`, Claude Code runs `.claude/`, and everything project-specific
lives in filled-in skeletons rather than in prompts.** That is what makes the same harness behave
correctly on a .NET monorepo and on a Python service.

### Why use it

AI can already write the code. What it does badly, left unsupervised, is everything around the code:
knowing this project's conventions, proving the change works, and stopping before something
irreversible. Each mechanism below answers a specific failure mode.

| Without a harness | What the harness does |
|---|---|
| You re-explain the stack, conventions and domain every session — and the answers drift | The filled `.ai/config/` and `.ai/context/` are loaded automatically, scoped to the task. The project's rules are a file, not a memory of a prompt |
| Output quality depends on how well you phrased today's prompt | Personas and playbooks fix the *method*. `/agents:review` applies the same severity vocabulary on a Friday as on a Monday |
| AI-written code lands with a glance, because reviewing it is slower than accepting it | Reviewer and security scanner run **in parallel**, in separate contexts, and report rather than fix. CRITICAL findings block the commit — the gate isn't optional and isn't yours to forget |
| The code passed review and tests — but nobody called the API or clicked through the screen | Runtime verification: after review and security, real API calls, a browser run of the journeys and read-only DB checks against the test environment. Failed or skipped planned checks block the commit until you accept them |
| "Tests pass" — but nobody checks whether tests exist for that scope | Verification is scope-aware: real tests where a runner exists, a clean build plus a documented manual reproduction where none does, and the report states which happened |
| One bad command — a force push, a hard reset, a deploy to prod — undoes a day | Hooks **hard-block** them at the tool call, before the model's intent matters |
| Why a decision was made lives in a Slack thread that's now gone | Append-only `decisions`, `learnings` and `design-taste` logs. The designer reads rejected patterns before proposing, so a "no" stays a no |
| A long session loses the thread, and the next one starts cold | `STATE.md` records phase, tasks and decisions; re-running resumes and re-verifies each "done" phase's artifact before trusting it |
| Parallel work on one feature collides in the working tree | The epic path gives each sub-feature its own git worktree, merged in dependency order |
| Every repo grows its own private way of working with AI | The same harness, the same commands, the same gates across projects. A joiner learns it once |

**What it costs.** Ceremony. The full path — `/ba` → `/qa` → `/workflows:feature` with five STOP
gates — is built for work that deserves a spec. For a typo or a one-line fix that overhead is real
and not worth paying: use `/agents:dev` or `/workflows:bugfix` instead. The harness also can't make a
codebase testable, and it won't catch a bad decision you approve at a gate. It removes the failures
that come from forgetting, not the ones that come from judgment.

---

## 1. Prerequisites

| Need | Why it matters |
|---|---|
| **Claude Code** (CLI, desktop app, or IDE extension) opened at the repo root | Commands, sub-agents and hooks are discovered per repo from `.claude/` |
| **Bash** on `PATH` — Git Bash or WSL on Windows | All nine hooks are `.sh`. Without bash they fail quietly and every guardrail is off while looking installed |
| **git** | Branch guards, changelog/standup commands, and the epic path's worktrees |
| *(optional)* an MCP server | `.mcp.json` ships Atlassian (Jira/Confluence, OAuth), a Figma bridge and Playwright (fetched by `npx`). Authenticate once with `/mcp`. Everything degrades gracefully when not connected |
| *(for UI runtime checks)* **Claude in Chrome** | The default UI driver. Each developer starts Claude Code with `claude --chrome` (or `/chrome` → *Enabled by default*), installs the extension, and is signed in with `/login`. Without it, Playwright is used |

Quick check that bash is really there:

```bash
bash -c 'echo bash-ok' && git --version
```

---

## 2. Copy the harness into your project

From a clone of this repo, copy into your project's repo root:

```
.ai/  .claude/  .mcp.json  CLAUDE.md  AGENTS.md  COMMANDS.md  README.md
```

`.claude/HARNESS_VERSION` comes along with `.claude/`: it records which template release you copied
(it matches a `v<version>` tag here), and `/init-project` notes it in `.ai/memory/decisions.md`.
Leave it as it is — later, `git log v<version>..` in this repo lists everything you don't have yet.

Optionally bring `examples/fleetkeep/` along while you configure — it is a fully worked version of
every file you are about to fill in, and `/init-project` offers to delete it at the end.

**Do not copy this repo's `.gitignore`.** It is written for the template itself. The lines your project
must have:

```gitignore
.worktrees/
.ai/features/**/e2e-screenshots/
```

Do **not** ignore `.ai/features/` — the epic path commits planning artifacts onto the epic branch,
and git worktrees only see committed files. Do not ignore `.claude/agent-memory/` either: the
reviewer, security scanner, critic and harness engineer write what they learn there, and committing
it shares that with the team. `.claude/settings.local.json` is per-developer — ignore that one.

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
| Release deliverables | Whether someone outside the team deploys (turns on the deployment guide), its audience, a Word copy, the deployable units and rollout order |

Prefer to do it by hand, or to adjust later? [`.ai/CUSTOMIZATION.md`](../.ai/CUSTOMIZATION.md) maps
all 13 variability axes to the exact files and tokens they own.

**Shape the tree while you are there:**

- **Single-project repo** → delete the `backend/` and `frontend/` subfolders under `.ai/config/`,
  `.ai/context/` and `.ai/standards/project/`. Scope detection collapses to one scope.
- **No UI at all** (headless / API-only) → delete `.ai/standards/project/frontend/design/`.
- The per-stack folders (`standards/project/backend/{dotnet,node}`,
  `standards/project/frontend/{react,angular}`) and `standards/universal/vcs/*` are
  **reference-only** — agents never read them. Copy what fits into your `tech-specific.md`, then
  delete the stacks you don't use.

---

## 4. Verify

Nothing unfilled should remain:

```bash
grep -rnE '\{\{[A-Z][A-Z0-9_]*\}\}' .ai .claude CLAUDE.md | grep -vE 'CUSTOMIZATION.md|agents/harness-|workflows/harness-improvement|commands/init-project.md|standards/project/[a-z]+/(dotnet|node|react|angular)/|standards/universal/vcs/|examples/'
```

Empty output means done. It scans `.claude/` as well as `.ai/` — commands and sub-agents carry
tokens too, and an unfilled one there is invisible until a command misbehaves. The exclusions are
deliberate: `CUSTOMIZATION.md`, `init-project.md` and the harness-maintenance docs discuss token
*names*, and the per-stack and VCS files are references you copy from.

**Then check the guardrails are actually on.** `.claude/hooks/hooks.env` is the single config for
all hook behaviour and it is **inert-safe** — a blank value or `*_CHECK="off"` skips that check
silently. An un-customised file blocks nothing while looking fully installed. At minimum set:

| Key | Effect if unset |
|---|---|
| `PROTECTED_BRANCHES` | Direct pushes to main/develop are not blocked |
| `TYPECHECK_CMD` / `LINT_CMD` + `PACKAGE_DIRS` | No type-check or lint runs after edits |
| `MIGRATIONS_GLOB` | Generated migrations can be hand-edited without warning |
| `SENSITIVE_CONFIG_GLOBS` | No warning before editing secrets-bearing config |
| `TENANT_ISOLATION_CHECK` + `TENANT_KEY` | No tenant-scoping check on data-access edits |

Smoke-test one hook — on a protected branch, ask Claude to run `git push --force` and confirm it is
refused.

---

## 5. Your first feature

The studios produce the specs; the workflow consumes them. It will not generate them for you.

```
/ba  <feature-slug>      # requirement-spec.md + user-stories.md (or epic-breakdown.md for an epic)
/qa  <feature-slug>      # test-specs.md, derived from the above
/workflows:feature <feature-slug>
```

What to expect from `/workflows:feature`:

1. It reads the BA/QA artifacts and **stops** if any are missing.
2. It writes `STATE.md` — the machine-maintained record of phase, tasks, decisions and next action.
   Re-running the command later **resumes** from it, verifying each "done" phase really produced its
   artifact before trusting it.
3. It determines scope (backend / frontend / fullstack) and loads only that scope's context.
4. It writes a technical spec and **stops for your approval**, asking once whether to enable
   per-task atomic commits.
5. If there is a UI surface, the design gate runs: UX → visual design → an Artifact preview → your
   approval loop.
6. Implementation is delegated to a developer sub-agent with fresh context.
7. Verification follows the scope's gates: real tests where a test runner exists; a clean build plus
   a documented manual reproduction where none does — and it states which it did.
8. Reviewer and security scanner run **in parallel** on the diff. CRITICAL findings block the commit.
9. It **stops** before committing, and again before opening the pull request.

There are five STOP gates in that workflow. They are the point of it — the harness is built so a
human approves the spec, the design, the commit and the PR.

Everything lands under `.ai/features/<slug>/`, each document carrying your branded header.

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
| Record a lesson learned | `/utils:learn "<one-liner>"` — area-specific lessons can become a `.claude/rules/` file |
| A question about the harness itself | `/harness:ask "<question>"` |

---

## 6. Keeping it healthy

- **Memory grows with the project.** `.ai/memory/decisions.md`, `learnings.md` and `design-taste.md`
  are append-only logs that agents read before acting and write to after. They are the difference
  between an assistant that repeats a mistake and one that doesn't.
- **Change the harness with `/harness:improve`**, not by hand-editing prompts. It runs an
  author → critic → revise → recheck loop with an integration audit against the harness's own
  invariants.
- **Revisit `hooks.env`** when the stack changes — a new test runner means `TDD_CHECK` becomes
  satisfiable; a new UI means the design-token check becomes useful.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Hooks never fire | No bash on `PATH` (common on Windows) | Install Git Bash / WSL; re-test with `bash -c 'echo ok'` |
| Hooks fire but nothing is ever blocked | `hooks.env` still inert | Fill `PROTECTED_BRANCHES`, the command keys, and the `*_CHECK` toggles |
| A workflow says artifacts are missing | The studios haven't run | `/ba <slug>` then `/qa <slug>` first |
| Agents cite the wrong stack | A `tech-specific.md` or `project-config.md` is still a skeleton | Re-run the verify grep from step 4 |
| A command loads too much context | Scope detection guessed wide | `/utils:scope backend` (or `frontend`) for the session |
| Resume picks up in the wrong place | `STATE.md` claims a phase is done but its artifact is missing | The workflow re-runs it automatically; delete `STATE.md` to start clean |
| Generated docs have no logo/footer | `.ai/config/branding.md` unfilled | Fill it and drop a logo in `.ai/branding/` |
