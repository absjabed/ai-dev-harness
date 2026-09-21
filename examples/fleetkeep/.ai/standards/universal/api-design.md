# API Design (Universal)

REST principles for any HTTP API in this org.

- **Nouns in URLs, verbs via HTTP methods.** `POST /reservations`, not `POST /createReservation`.
- **Plural resource names.** `/cars`, `/users`, `/reservations`.
- **Consistent error format** across every endpoint. (This project: see the mapping table below.)
- **Consistent success format.** (This project: the `ApiResponse<T>` — `{ data, error, traceId }` envelope.)
- **Version your APIs** — `/v1/...` (or a version header) — so breaking changes don't break
  clients. *(Not yet applied here; add when introducing breaking changes.)*
- **Paginate list endpoints.** Any endpoint returning a collection should support pagination
  (limit/offset or cursor). *(Not yet applied to `GET /cars`, `GET /users` — add before these
  grow.)*
- **Meaningful HTTP status codes.** `200` success, `201` created, `400` validation, `401/403`
  auth, `404` not found, `409` conflict, `5xx` server. Never return `200` with an error body.
- **Validate requests and responses**; return clear, actionable validation messages.
- **Document every public endpoint** (method, path, params, request/response shape, errors).

## Mapping to this project

FleetKeep's concrete conventions:

| Concern | Convention here |
|---------|-----------------|
| Success | `ApiResponse<T>` — `{ data, error, traceId }` envelope, `201` on create else `200` |
| Errors | consistent error envelope with a stable machine-readable `code` (e.g. `NOT_FOUND` / `CONFLICT` / `VALIDATION_ERROR`) |
| Validation | FluentValidation at the route boundary |
| Not found | throw the not-found error type → `404` |
| State conflict | throw the conflict error type → `409` |
