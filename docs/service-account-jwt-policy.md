Service account JWT policy for server→worker calls

Purpose
- Define the minimal JWT structure and policy for services that need to call the Meilisearch Worker on behalf of servers (not end users).

Policy
- Token audience (`aud`) must be `meilisearch-worker`.
- Issuer (`iss`) must be the issuing service id (e.g., `data-service`, `content-skimmer`).
- `sub` should contain the service account id (e.g., `svc-content-skimmer`).
- `scope` claim must be an array or space-delimited string listing allowed actions. Examples:
  - `search` - allow search operations
  - `index` - allow index/add/update
  - `delete` - allow delete operations
  - `admin` - reserved and only for human-approved operations
- `exp` must be short-lived for service tokens that perform writes; recommended lifetime: 5 minutes for write tokens, up to 1 hour for read-only tokens.
- Tokens MUST be signed with HMAC-SHA256 using `AUTH_JWT_SECRET` or with an asymmetric key pair managed by platform secrets.

Enforcement in Worker
- The Worker must validate `aud`, `iss`, `sub`, `scope`, and `exp`. Requests without required scope should be rejected with 403.
- For index/delete operations, worker should prefer short-lived tokens and log the `sub` and `iss` for auditability.

Rotation and issuance
- Service tokens should be issued by a central token service or CI/CD secrets manager. Long-lived static secrets in code/config are disallowed.
