<!-- Report shape for runtime verification (.ai/workflows/runtime-verification.md). Written to
     .ai/features/<slug>/test-specs/e2e-report.md, or .ai/reports/e2e-<YYYY-MM-DD>-<slug>.md for
     ad-hoc work. Starts with the branded header from .ai/templates/artifact-header.md.
     Never a token, password, cookie or personal data in it — `<redacted>`, counts and ids only. -->
# Runtime Verification: [feature / bug / task]

## Summary

| Result | Count |
|---|---|
| PASS | [n] |
| FAIL | [n] |
| NOT RUN | [n] |

**Verdict:** [all planned checks passed | blocked — n FAIL / n NOT RUN | passed with accepted gaps]

## Plan (as confirmed)

| Level | Why | Driver / tool | Target |
|---|---|---|---|
| [API \| UI \| DB] | [what in the change made it necessary] | [curl \| Claude in Chrome \| Playwright \| e2e command \| <db MCP server>] | [base URL / UI URL / database] |

**Not checked, by decision:** [level/check — reason | none]

## Environment

- **Commit / diff:** [hash or "uncommitted on <branch>"]
- **API base URL:** [url] · **UI URL:** [url] · **Database:** [name, read-only via <server> | n/a]
- **Test identity:** [test account / role used — never its credentials]

## API checks

| # | Check | Request | Expected | Actual | Result |
|---|---|---|---|---|---|
| A1 | [happy path — create X] | `POST /api/v1/...` | 201 + body has `id` | [status + key fields] | [PASS \| FAIL \| NOT RUN] |

## UI checks

| # | Journey | Steps | Evidence | Console / network | Result |
|---|---|---|---|---|---|
| U1 | [journey from test-specs.md] | [short step list] | [screenshot path or description] | [errors \| clean] | [PASS \| FAIL \| NOT RUN] |

## DB checks (read-only)

| # | Check | Query (SELECT only) | Expected | Actual | Result |
|---|---|---|---|---|---|
| D1 | [row written for A1, tenant key set] | `SELECT ... WHERE id = ...` | [1 row, tenant = test tenant] | [counts / ids] | [PASS \| FAIL \| NOT RUN] |

## Failures and gaps

- [#] — [what failed or why it did not run] — [fixed in <commit/change> and re-run | open | accepted by the user: "<their words>"]

## Test data left behind

- [ids created and not cleaned up, and how to remove them | none]
