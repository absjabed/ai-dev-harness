---
description: Force a development scope for this session — backend, frontend, fullstack, or auto
allowed-tools: Write
---

Set or clear the forced scope to: **$ARGUMENTS**

Write the appropriate content to `.ai/config/current-scope.md` based on the argument:

---

## If argument is `backend`

```
# Forced scope: backend

All agents must load only backend context files — do NOT load frontend files.

Backend files to load:
- `.ai/config/backend/project-config.md`
- `.ai/context/backend/architecture.md`
- `.ai/context/backend/project-overview.md`
- `.ai/context/backend/business-rules.md`
- `.ai/standards/project/backend/tech-specific.md`
```

## If argument is `frontend`

```
# Forced scope: frontend

All agents must load only frontend context files — do NOT load backend files.

Frontend files to load:
- `.ai/config/frontend/project-config.md`
- `.ai/context/frontend/architecture.md`
- `.ai/context/frontend/project-overview.md`
- `.ai/context/frontend/business-rules.md`
- `.ai/standards/project/frontend/tech-specific.md`
```

## If argument is `fullstack`

```
# Forced scope: fullstack

All agents must load both backend and frontend context files.

Backend files to load:
- `.ai/config/backend/project-config.md`
- `.ai/context/backend/architecture.md`
- `.ai/context/backend/project-overview.md`
- `.ai/context/backend/business-rules.md`
- `.ai/standards/project/backend/tech-specific.md`

Frontend files to load:
- `.ai/config/frontend/project-config.md`
- `.ai/context/frontend/architecture.md`
- `.ai/context/frontend/project-overview.md`
- `.ai/context/frontend/business-rules.md`
- `.ai/standards/project/frontend/tech-specific.md`
```

## If argument is `auto` or empty

```
# Scope: auto

Agents determine scope from the task description. No forced scope is active.

To force a scope for the whole session, run `/utils:scope backend`, `/utils:scope frontend`,
or `/utils:scope fullstack`. Run `/utils:scope auto` to return to auto-detection.
```

---

After writing the file, confirm: "Scope set to **$ARGUMENTS**."
