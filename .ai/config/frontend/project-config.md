<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Frontend Project Config

## Identity
**Project**: {{PROJECT_NAME}} — Frontend
**Root directory**: `{{FRONTEND_DIR}}`
**Framework**: {{FRONTEND_FRAMEWORK}}
**Language**: {{FRONTEND_LANGUAGE}}
**Dev server**: > [FILL IN: dev server port]
**Backend API**: > [FILL IN: env var / mechanism used to point the client at the backend]

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Framework | {{FRONTEND_FRAMEWORK}} |
| Build tool | > [FILL IN: build tool] |
| Routing | > [FILL IN: router library] |
| Auth | {{AUTH_PROVIDER}} |
| Styling | > [FILL IN: styling system] |
| UI primitives | > [FILL IN: component library] |
| Forms / validation | {{VALIDATION_LIB}} |
| Data fetching | > [FILL IN: data-fetching library + HTTP client] |
| Real-time | > [FILL IN: real-time transport, if any] |

## Development Commands
```bash
{{INSTALL_CMD}}   # Install dependencies
{{DEV_CMD}}       # Dev server
{{BUILD_CMD}}     # Production build
{{LINT_CMD}}      # Lint
{{TEST_CMD}}      # Test
```

## Project Structure
```
{{FRONTEND_DIR}}/
└── {{SOURCE_DIR}}/
    ├── ...          # > [FILL IN: app entry + route declarations]
    ├── components/  # > [FILL IN: component organisation, e.g. atomic design layers]
    ├── ...          # > [FILL IN: shared state (contexts / stores)]
    ├── ...          # > [FILL IN: hooks]
    └── ...          # > [FILL IN: API clients, services, config]
```

## Environment Variables
```bash
# > [FILL IN: list client-exposed env vars and their purpose.
#   Use your framework's required prefix — never commit secrets to the client bundle.]
```

## Conventions
- **Component organisation**: > [FILL IN: naming + folder rules, e.g. atomic design hierarchy]
- **Path alias**: > [FILL IN: import alias, e.g. `@` → source root]
- **All API calls go through a single client layer**: never call `fetch()` / the HTTP client directly in components
- **Server state**: > [FILL IN: preferred server-state pattern and where it lives]
- **App state**: cross-component state lives in a shared store/context — avoid prop-drilling more than a couple of levels
- **Auth tokens**: > [FILL IN: how tokens are attached to requests — usually automatic, do not manage manually]
- **Env vars**: access via your framework's client-safe mechanism — never read server-only secrets in the browser

## Never Do
- Call `fetch()` / the raw HTTP client directly in components — use the API layer
- Read server-only secrets or the wrong env mechanism in browser code
- Hardcode API URLs — use configuration / env vars
- Manage auth tokens manually when the auth provider handles them
- Put business logic or API calls inside component files — use hooks / services
- Use default exports for components (prefer named exports)
