---
description: QA Studio — generate a branded test spec from a feature's requirement + user stories (single feature or epic)
argument-hint: <feature-name>
allowed-tools: Read, Write, Edit, Bash
---
@.ai/agents/qa-studio-agent.md
@.ai/standards/universal/testing-principles.md
@.ai/config/branding.md
@.ai/templates/artifact-header.md
@.ai/templates/test-plan.md

**Scope determination (do this first):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope.
2. Otherwise infer scope from the feature's requirement (server-side vs UI vs both).
3. Load the matching context (`.ai/context/**` for the scope; single-project repos load the root context files).

Feature/Epic: $ARGUMENTS

Operate as the **QA Studio agent**. Look under `.ai/features/<slug>/`: **if `epic-breakdown.md`
exists, treat it as an epic** and design a `test-specs.md` for each sub-feature (reading each
`<sub-feature>/requirement-spec.md` and `user-stories.md`); otherwise read the single feature's
`requirement-spec.md` and `user-stories.md`. Ask the tester to run `/ba <slug>` first if the inputs
are missing. Interview the tester to close coverage gaps, then write the branded test spec(s) —
`.ai/features/<slug>/test-specs.md` for a single feature, or
`.ai/features/<slug>/<sub-feature>/test-specs.md` per sub-feature for an epic — each beginning with
the rendered branded header from `.ai/templates/artifact-header.md`. `/workflows:feature` consumes
these and never regenerates them.
