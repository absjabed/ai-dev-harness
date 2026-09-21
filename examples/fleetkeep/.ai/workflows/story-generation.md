# Workflow: Story Generation

1. **Clarify** — Understand the **business goal**, not just the feature request. Why is this
   wanted, and what outcome defines success?
2. **Identify actors** — Who are the users/roles involved? (e.g. customer vs fleet operator.)
3. **Classify: single feature or epic?** — If the request spans several distinct capabilities with
   independent acceptance criteria, treat it as an **epic**: write `epic-breakdown.md` (epic name;
   ordered sub-features, each with a slug / one-line description / scope / dependencies; and
   dependency groups), then run steps 4–9 per sub-feature. Otherwise treat it as a single feature.
4. **Map journeys** — Walk the happy paths and the edge cases for each actor. Cross-reference
   `.ai/context/business-rules.md`.
5. **Write stories** — One story per user journey, using `.ai/templates/user-story.md`
   (As a… / I want… / so that…).
6. **Write acceptance criteria** — Given/When/Then for each story, including error and
   edge-case branches.
7. **Identify dependencies** — What must exist first (data, endpoints, an unresolved business
   rule from the "Rules to Fill In" list)?
8. **Estimate complexity** — T-shirt size (S / M / L / XL); break down anything XL.
9. **Flag risks** — Technical unknowns, rule ambiguities, or security/perf concerns.

**Output:** committable markdown stories, each self-contained. For an epic, an `epic-breakdown.md`
plus per-sub-feature stories under each `<sub-feature>/`.
