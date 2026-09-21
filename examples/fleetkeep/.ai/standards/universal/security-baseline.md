# Security Baseline (Universal)

Every agent applies this checklist; the Reviewer agent enforces it.

- **No hardcoded secrets.** Credentials, API keys, tokens, and connection strings come from
  environment variables / a secret manager — never source code or commits.
- **Validate all inputs.** Trust nothing from outside the system; validate type, shape, and
  bounds at the boundary (using FluentValidation).
- **Parameterized queries only.** Never string-concatenate SQL. (EF Core 8 parameterizes for us —
  don't bypass it with raw, interpolated SQL.)
- **Least privilege.** Grant the minimum permissions needed — for DB users, IAM roles, tokens.
- **Sanitize outputs.** Prevent injection (XSS/log/command) when rendering or forwarding data.
- **HTTPS everywhere.** No plaintext transport for anything sensitive.
- **Log security events, not PII.** Record auth attempts and permission changes; never log
  passwords, tokens, or personal data.
- **Keep dependencies updated.** Flag outdated or vulnerable packages; prefer patched versions.
- **Tokens must expire.** Auth tokens/sessions have sensible TTLs; no never-expiring credentials.
- **OWASP Top 10 awareness.** Flag injection, broken auth/access control, sensitive-data
  exposure, SSRF, insecure deserialization, and misconfigurations when you see them.

## Project note

This project authenticates with Microsoft Entra ID (all endpoints require valid credentials —
OIDC authorization-code + PKCE in the SPA (MSAL), JWT bearer validated by the API) and enforces tenant isolation: every query is scoped to the caller's tenant by the `TenantId` global query filter on `FleetKeepDbContext`. Violating
tenant isolation is a critical security BLOCKER.
