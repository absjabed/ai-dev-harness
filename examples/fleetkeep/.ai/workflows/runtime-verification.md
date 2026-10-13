# Workflow: Runtime Verification

Proves the change works **against a running system** — real HTTP calls to the API, a real browser
driving the UI, and a read-only look at the database — after code review (and the security scan,
where the workflow runs one) has passed and before the commit. Unit and integration tests prove the code; this proves the product.

Used by `/workflows:feature` (single feature: command step 5b, playbook step 7a; epic: Phase F
step 0a), `/workflows:bugfix` (step 7a, focused on the original bug), `/workflows:hotfix` (step 5a,
smoke only) and, for anything else — ad-hoc work, a `/agents:dev` change — `/workflows:verify`.

Runs in the **orchestrating session**, not a sub-agent: you confirm the plan, handle any login
page, approve the browser's site prompts, and decide on failures. Environment values come from
`.ai/config/project-config.md` → **Test environments**.

## 1. Plan — propose levels from the change, then ask once

Read the diff (`git diff HEAD`, or the branch diff for an epic) and, where they exist,
`requirement-spec.md`, `test-specs.md` and `deploy-notes.md`. Propose the levels the change
actually needs:

| Level | Propose it when the change touches | Typical checks |
|---|---|---|
| **API** | endpoints, handlers, request/response contracts, validation, auth/authorization, tenancy | happy path; validation (400); unauthenticated (401); wrong role (403); another tenant's resource (404/403); not found; conflict (409); response shape against the spec |
| **UI** | pages, components, client state, routing, styling, forms, client-side calls | the journeys in `test-specs.md`; form validation messages; empty / error / loading states; no console errors; no failed network calls |
| **DB** | schema, migrations, data access, tenant filters, backfills, anything the API/UI step should persist | rows written or changed as expected; tenant key set; nothing written for another tenant; migration recorded; no unintended rows |

Show the plan as a table — level, why, the checks, the target URL, the driver (for UI) — plus
anything that will **not** be checked and why. Then **ask once**: run as proposed, or edit (add or
drop a level or check, change the driver). A change with no runtime surface (docs only, a comment, a
build-script tweak) gets "no runtime verification — <reason>"; ask the user to confirm that too.
Record the confirmed plan in `STATE.md` (or at the top of the report when there is no `STATE.md`).

## 2. Preflight

1. **Target** — use only the URLs in *Test environments*. Never a production host: anything in
   `E2E_FORBIDDEN_HOSTS` (`.claude/hooks/hooks.env`) is hard-blocked by `e2e-guard.sh`, and any host
   you are unsure about — ask.
2. **Running?** — hit the configured health URL (`curl -sS -o /dev/null -w '%{http_code}' <url>`). If
   it is down, offer to start it with the configured start command (in the background), or ask the
   user to start it. Never point the checks somewhere else to get past this.
3. **Credentials** — API tests get a **test** token one of two ways, as *Test environments* says:
   - a **token command** substituted inline in each request (e.g.
     `-H "Authorization: Bearer $(<token command>)"`) — works in any session; or
   - an **environment variable** (e.g. `"$E2E_API_TOKEN"`) that the user exported **before starting
     Claude Code**. Shell state does not carry between the agent's tool calls, so an `export` run
     inside the session never reaches the next request. If the variable is empty, stop and ask the
     user to export it and restart, or to use the token command — don't go looking for one.
   Cross-tenant checks need a second identity (a second variable or command) for the other tenant.
   Never print a token, write it to a file or the report, or commit it.
   Browser logins are done **by the user**: when a login page or CAPTCHA appears, pause and ask.
   Never type a password.
4. **Drivers available?** —
   - **UI:** the configured default driver (*Test environments* → UI driver) first.
     - **Claude in Chrome** — available when the `mcp__claude-in-chrome__*` tools are present. A
       project cannot switch it on; if missing, tell the user it needs `claude --chrome` (or
       `/chrome` → *Enabled by default*), a claude.ai login, and the browser extension. It is not
       available in WSL or through third-party model providers.
     - **Playwright MCP** — available when Playwright's browser tools are present —
       `mcp__playwright__*` from the server `.mcp.json` ships (`npx` fetches `@playwright/mcp`), or a
       Playwright plugin's own tools.
     - Fallback order: the default driver → the other browser driver → the project's e2e test
       command (*Test environments*) → **not run**. Say which one was used and why.
   - **DB:** the read-only database MCP server named in *Test environments*. None configured →
     DB checks are **not run**; offer API-level evidence instead (a follow-up `GET`).

## 3. Run

### API
- One `curl` per check, against the configured base URL:
  `curl -sS -X <METHOD> "<base>/<path>" -H "Authorization: Bearer $TOKEN_VAR" -H 'Content-Type: application/json' -d '<body>' -w '\n%{http_code}'`
  — the variable stays unexpanded in what you show; the shell expands it.
- Record per check: method, path, the request body (secrets as `<redacted>`), expected vs actual
  status, and the relevant part of the response. Trim large bodies to what proves the point.
- Tenancy: if the product is multi-tenant, at least one check asks for another tenant's resource
  and must be refused. A leak is a **FAIL** and is CRITICAL.
- Note any record ids created, for the DB checks and for cleanup.

### UI
- **Claude in Chrome** — it drives the user's real Chrome profile with their logged-in sessions.
  Open a **new tab** at the configured UI URL only; never use, read or close the user's other tabs;
  never visit anything outside the configured URLs; stop and ask before any action that sends
  email, moves money, or would act on a real account. Pause for the user at login and CAPTCHA.
  **Before the first journey, confirm who is signed in:** read the signed-in user shown by the app
  and check it is one of the test accounts in *Test environments*. Single sign-on can silently log
  the browser in as the developer's real account — if the identity is not a listed test account,
  stop and ask the user to sign in as one (or switch to Playwright).
- **Playwright** — a clean, isolated browser; same journeys, same rules.
- Per journey: the steps, a screenshot at each meaningful state, console errors after each page
  action, and failed (4xx/5xx) network calls. Screenshots are **local evidence, never committed**:
  save them under `test-specs/e2e-screenshots/` (which the project's `.gitignore` excludes —
  `.ai/features/**/e2e-screenshots/`) when the driver can save to disk, otherwise describe them.
  A screenshot of a logged-in page can show personal data or tokens.

### DB (read-only)
- `SELECT` only — never `INSERT`, `UPDATE`, `DELETE`, DDL or a stored procedure that writes, even
  against a local database. If the server is not enforcing read-only, you still are.
- Check what the API/UI steps should have persisted (by the ids recorded), the tenant key on new
  rows, the migration-history entry for a new migration, and that no other tenant's rows changed.
- Report the query and a trimmed result. Never paste personal data — counts and ids only.

### Cleanup
Remove test data the checks created **through the API** where the spec defines a way; otherwise
list it in the report for the user. Never clean up with database writes.

## 4. Report

Write the report from `.ai/templates/e2e-report.md` to
`.ai/features/<slug>/test-specs/e2e-report.md` (ad-hoc work without a feature folder:
`.ai/reports/e2e-<YYYY-MM-DD>-<short-slug>.md`), opening with the branded header. Every planned check
gets a result: **PASS**, **FAIL**, or **NOT RUN** (with the reason). Never mark a check PASS on
inference — only on observed evidence.

The report is written after the review and the security scan, so nothing has scanned it: **never
put a token, password, cookie, connection string or personal data in it** — `<redacted>`, ids and
counts only — and re-read it for those before the commit STOP.

## 5. Gate

- **FAIL** blocks the commit. Fix the cause, then re-run the failed checks (and any check the fix
  could affect) and update the report.
- A **planned check that did NOT RUN** counts as a failure for the gate — confidence that was
  planned and not obtained is a gap, not a pass.
- The user may **explicitly accept** a failure or a not-run check instead. Record each acceptance —
  the check, the reason, the user's words — in `STATE.md` and, when there is one, the
  pull request description. Never accept on the user's behalf.
- The commit STOP shows the report summary: counts per result, every FAIL and NOT RUN, and any
  acceptance — and confirms the report holds no secret or personal data.

## Never

- Run a check against production, or against a host you are unsure is non-production. Post-deploy
  production checks belong to a human or to CI — `e2e-guard.sh` blocks the agent from production
  hosts for any purpose.
- Print, store or commit a token, password or cookie.
- Write to the database.
- Use a real person's data; use the test accounts named in *Test environments*.
- Report a check as passed that you did not observe passing.
