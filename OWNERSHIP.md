Owners and responsibilities

- Platform Search Team (@platform-search-team): Meilisearch Worker, index configuration, CI checks, deployments.
- Content Team (@content-team): content-skimmer and content-store-service - produce indexable metadata/events.
- Data Team (@data-team): D1 canonical metadata, event schemas, producers for file.created/updated/deleted.
- Platform Team (@platform-team): CI/CD and secrets management.

Rules:
- Only the Meilisearch Worker is allowed to write or delete documents in Meilisearch indexes. Clients must use the Worker HTTP API for indexing.
- Admin keys for Meilisearch must never be committed or stored in client-side configs. Use environment secrets and the Worker.
- Exceptions require approval and explicit notes in this file.
