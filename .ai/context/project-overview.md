<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Project Overview

> Read this first to understand *what* this system is and *who* it serves, before touching code.

## What this system does

**{{PROJECT_NAME}}** — {{PROJECT_TAGLINE}}.

> [FILL IN: 3-6 sentences describing what the product does and the value it delivers.
> Cover {{PROJECT_PURPOSE}} and the primary capabilities. Use a short bulleted list of the
> core value propositions if that reads more clearly — one line each.]

This repository is a {{REPO_TOPOLOGY}}. Its scopes are: {{SCOPES}}.

> [FILL IN: one line per subsystem/scope describing its role — e.g.
> "{{BACKEND_DIR}} — API service; {{FRONTEND_DIR}} — web app". Omit scopes you do not have.]

## Who uses it

> [FILL IN: list your primary user personas ({{TARGET_USERS}}), one bullet each with a one-line
> description of what that persona does in the system. 3-8 personas is typical.]

> [FILL IN (if multi-tenant): describe your tenant/isolation model in one line — see
> {{TENANT_ISOLATION_RULE}}. Delete this note if the product is single-tenant.]

## Core user journeys

> [FILL IN: list your 6-8 core end-to-end user journeys, one line each. A journey should read as
> "actor does X → system responds with Y". These become the backbone for feature planning and QA.]

## Most important modules

> [FILL IN: list the 6-10 highest-value or highest-traffic modules/files a new engineer should
> know first. One bullet each: `path/to/module` — one-line purpose. Prefer stable, load-bearing
> code (core services, route definitions, infra entry points).]

## What "done" looks like for a change here

> [FILL IN: your definition of done. Keep it to concrete, checkable statements. Suggested items:]
> - The change respects scope boundaries and existing patterns ({{LAYERING_PATTERN}},
>   {{ROUTING_PATTERN}}, {{DATA_ACCESS_LAYER}}).
> - Security invariants are preserved (auth enforced via {{AUTH_MECHANISM}};
>   isolation via {{TENANT_ISOLATION_RULE}} where applicable).
> - Schema/data changes go through the sanctioned migration path for {{ORM}}/{{DATABASE}}.
> - Tests are written for the change and the lint + test commands pass.
> - The changed flow is manually verified against the relevant dev server.
