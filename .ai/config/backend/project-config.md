<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Backend Project Config

## Identity
**Project**: {{PROJECT_NAME}} — Backend API
**Root directory**: `{{BACKEND_DIR}}`
**Runtime**: {{BACKEND_RUNTIME}}
**Language**: {{BACKEND_LANGUAGE}}
**Framework**: {{BACKEND_FRAMEWORK}}
**Cloud provider**: {{CLOUD_PROVIDER}}
**Runtime defaults**: > [FILL IN: e.g. region, timeout, memory — remove if not applicable]

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Language | {{BACKEND_LANGUAGE}} |
| API framework | {{BACKEND_FRAMEWORK}} |
| ORM | {{ORM}} |
| Database | {{DATABASE}} |
| Auth | {{AUTH_PROVIDER}} ({{AUTH_MECHANISM}}) |
| Cloud services | > [FILL IN: cloud services used, e.g. object storage, queues, secrets] |

## Development Commands
```bash
{{INSTALL_CMD}}      # Install dependencies
{{DEV_CMD}}          # Local dev server
{{BUILD_CMD}}        # Build
{{TYPECHECK_CMD}}    # Type-check
{{LINT_CMD}}         # Lint
{{TEST_CMD}}         # Test
{{MIGRATE_CMD}}      # Apply DB migrations
```

## Project Structure
```
{{BACKEND_DIR}}/
└── {{SOURCE_DIR}}/
    ├── ...            # > [FILL IN: request/route layer]
    ├── ...            # > [FILL IN: business-logic / service layer]
    ├── ...            # > [FILL IN: data-access layer — {{DATA_ACCESS_LAYER}} + {{MIGRATIONS_DIR}}]
    └── ...            # > [FILL IN: shared utils, logging, validation]
```

## Conventions
- **Handlers are thin**: validate request → call service → return response. No business logic.
- **Service layer owns business logic**: > [FILL IN: where services live and how they are named]
- **Data access is isolated**: only import persistence via {{DATA_ACCESS_LAYER}} — never from handlers or services directly
- **Routing pattern**: {{ROUTING_PATTERN}}
  > [FILL IN: how routes are declared and dispatched]
- **Tenant isolation**: {{TENANT_ISOLATION_RULE}}
- **Response shape**: use {{RESPONSE_ENVELOPE}} for all responses; never construct raw error objects in handlers

## Never Do
- Call the database / persistence layer directly from a handler file
- Return raw ORM / database objects to clients — map to response types
- Hardcode resource names or cloud service identifiers — use config / env vars
- Add business logic to the routing layer
- Commit secrets or credentials
