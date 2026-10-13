# Harness Improvement Workflow

How to change the harness itself — its agents, commands, workflows, hooks, standards, or
templates — without breaking what makes it trustworthy. Every improvement runs an
**author → critic → revise → recheck** loop: authored changes are adversarially verified
before they land. Used by `/harness:improve`.

> This workflow governs changes to the **harness machinery** (`.ai/` structure, `.claude/`
> commands/agents/hooks). Product features belong in `feature-development.md`.

## Invariants (the critic's checklist — violating any of these is a CRITICAL defect)

1. **Two-layer split** — `.ai/` is knowledge (Markdown only, nothing executes);
   `.claude/` is execution (commands, sub-agents, hooks). Never mix.
2. **Three-layer agent pattern** — behavior lives once in `.ai/agents/<name>-agent.md`;
   a slash command in `.claude/commands/**` adapts it for interactive use; an optional
   sub-agent in `.claude/agents/` adapts it for Task delegation. Commands and sub-agents
   defer to the persona — they never duplicate its rules.
3. **Template genericness** *(applies to the template repo — files still holding
   `{{TOKENS}}`/`[FILL IN]` blocks; once `/init-project` has filled a project in, its
   filled values are legitimate)* — root template files stay stack-agnostic: `{{TOKENS}}`
   and `> [FILL IN: …]` blocks, no project-specific names (frameworks, ORMs, cloud
   services) outside comments or `e.g.` examples.
4. **Inert-safety** — every hook check is opt-in via `.claude/hooks/hooks.env`; a blank
   value or `*_CHECK="off"` must mean *exactly* the pre-change behavior. Warnings go to
   stderr; hooks exit 0 unless they are a deliberate hard block (`exit 2`).
5. **Gate integrity** — never weaken, reorder around, or make skippable an existing STOP
   gate or hard block. New autonomy (auto-commits, spawned agents, external writes) is
   opt-in and sits *behind* a gate, off by default.
6. **Mirror invariant** *(only while `examples/` exists — it is deleted in real projects)* —
   the `.claude/hooks/*.sh` scripts stay byte-identical between the root and
   `examples/<example-project>/`; only `hooks.env` differs. Portable files copied into the example
   stay verbatim copies. **If `examples/` is absent, skip all mirror steps — never
   recreate the folder.**
7. **Docs inventories stay true** — `COMMANDS.md`, `README.md`, `AGENTS.md`, `.ai/README.md`,
   `.claude/README.md`, `.ai/CUSTOMIZATION.md`, and everything under `docs/`
   (`getting-started.md`, `components.md`, `portability.md`, and the hand-written
   `index.html`) enumerate commands, agents, sub-agents, hooks, templates, memory files and
   hook toggles — several of them by **count** as well as by name. Any addition/rename updates
   every list that names it, and any count it changes. `docs/index.html` is not generated:
   edit it in the same change as the markdown it mirrors.
8. **Tool least-privilege** — command/sub-agent frontmatter grants only the tools the role
   needs; anything the instructions tell the agent to run must be grantable from its
   `allowed-tools`/`tools` line (e.g. `date +%F` needs Bash).

## Integration rules (tools & MCP)

Apply whenever a change connects an external tool or MCP server, or teaches an agent to
use one. These extend the invariants above — violating one is likewise a CRITICAL defect.

9. **No secrets in config** — `.mcp.json` (and any connector config) holds no tokens,
   keys, or passwords: OAuth-based servers, local servers, or env-var references only.
   Committed config must be safe to read aloud.
10. **Per-command grants** — MCP tools are granted in the frontmatter of the specific
    commands/sub-agents that need them (e.g. `mcp__<server>__*` on `/ba` for issue
    intake), never globally. Invariant 8 applies to MCP tools exactly as to built-ins.
11. **Outward writes sit behind gates** — any action that writes outside the repo
    (create/transition a ticket, post a comment, publish a design) follows the STOP gate
    convention: show the user exactly what will be sent where, act only on explicit
    confirmation. Read-only intake (fetch an issue, read a design frame) needs no gate.
12. **Optional by default** — the harness must keep working with no server connected.
    Persona/workflow steps that use an integration are conditional ("if <server> is
    connected …") and degrade gracefully to the manual path when it is not.
13. **Agents never authenticate** — OAuth sign-ins, token entry, and starting local
    servers (e.g. a design tool's desktop MCP server) are the **user's** actions. A
    connection change ends with a STOP: the user authenticates and confirms the server
    is listed healthy (e.g. via `/mcp`), and agents build on it only after that
    confirmation.

## The loop

1. **Scope the improvement** — restate the goal; split it into work packages with
   **disjoint file sets** (packages run in parallel; overlapping files must share a package).
   List, per package: files to create/edit, the intended behavior, and which invariants
   it touches. STOP — confirm the plan with the user before editing.
2. **Author** — one harness-engineer agent per package (fresh context, this playbook +
   `.ai/CUSTOMIZATION.md` loaded). Shell changes MUST be exercised for real: `bash -n`
   plus smoke runs with fake JSON payloads in a throwaway git repo — critique never
   substitutes for execution.
3. **Critique** — one critic agent per package (read-only, fresh context). It verifies
   every claim itself: reads the diff, checks every referenced path exists, traces hook
   code paths for inert-safety, diffs old vs new gates, greps root files for genericness.
   Severity: **CRITICAL** (breaks an invariant, loses work, wrong behavior) /
   **MAJOR** (wrong or misleading in a real run) / **MINOR** (polish). Only defects it
   actually verified — a suspicion it could not reproduce or confirm by reading is not
   a finding.
4. **Revise** — fix every CRITICAL and MAJOR (cheap MINORs too). A disputed finding is
   answered with evidence, not silence. Shell fixes re-run their smoke tests.
5. **Recheck** — a fresh critic confirms each CRITICAL/MAJOR fix landed and nothing new
   broke. Loop 4–5 until clean (cap: 2 rounds, then STOP and surface to the user).
6. **Integrate** — one cross-package audit: file ownership (nothing touched that no
   package owns), cross-file contracts (e.g. headings one file writes and another greps),
   the mirror invariant (if `examples/` exists), `bash -n` over all hooks, a
   broken-reference sweep, and the docs inventories (invariant 7).
7. **Verify & land** — run the full verification block below, show the user the diff
   summary and any open questions, then STOP — commit only on explicit approval, as a
   conventional commit on a `feature/…` branch (never directly on the default branch).
   **In the template repo**, when the change is released, bump `.claude/HARNESS_VERSION` **and**
   the version in the `docs/index.html` sidebar (`Setup &amp; component guide · v<version>`) — patch
   for fixes and docs, minor for new capability that needs no project action, major when an
   adopting project must act (a new token or config section to fill, a renamed command, a moved
   file) — and tag that commit `v<version>`. **In a project**, never edit it: it records the
   template release the project was set up from.

## Verification block (run before the final STOP)

```bash
bash -n .claude/hooks/*.sh                                  # every hook parses
grep -rn '{{' <changed root files>                          # tokens only where intended
# if examples/ exists:
for d in examples/*/; do for f in .claude/hooks/*.sh; do cmp "$f" "$d$f"; done; done
git diff --stat                                             # matches the plan's file list
# template repo only — the guide's sidebar shows the same version as the marker:
[ -f docs/index.html ] && { grep -qF "v$(cat .claude/HARNESS_VERSION)</span>" docs/index.html || echo "docs/index.html sidebar version != .claude/HARNESS_VERSION"; }
```

Plus: every `@.ai/...` include and path named in changed files exists; every doc
inventory that names a changed artifact was updated.

Integration changes additionally: the connector config parses (e.g.
`node -e "JSON.parse(require('fs').readFileSync('.mcp.json','utf8'))"`), contains no
secrets (invariant 9), and the run ends with the invariant-13 STOP — the user
authenticates and confirms the connection before any agent is taught to rely on it.

## Learning capture

After landing, append what the loop taught you (defects the critic caught, invariants
that were nearly violated, test gaps) to `.ai/memory/learnings.md` — format
`YYYY-MM-DD | harness-improvement | <learning> | harness-engineer`. Improvements to
*this playbook itself* go through this same workflow.
