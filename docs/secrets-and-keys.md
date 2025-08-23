MEILISEARCH keys and how to generate/use them

This project expects two Meilisearch keys:

- MEILISEARCH_API_KEY — Admin API key used by the Worker to perform write operations (add/update/delete, index configuration). This key must be stored as a secret and never exposed to clients.
- MEILISEARCH_SEARCH_KEY — Public or limited search-only key used by read-only clients. The Worker creates a separate search client using this key.

How to generate
- If you're running Meilisearch-managed (hosted), create API keys in the Meilisearch dashboard. Create one admin key and one search-only key.
- If running self-hosted Meilisearch, start the server with a master key and then use the master to create scoped keys:
  - Use the master key to call the /keys endpoint and create a key with "actions": ["search"] for the search key.
  - Create an admin key for the Worker with full privileges.

How to set in GitHub Actions
- Add the following repository secrets:
  - MEILISEARCH_HOST (e.g., https://meili.example.com)
  - MEILISEARCH_API_KEY
  - MEILISEARCH_SEARCH_KEY

How to use locally for testing
- For local Worker development, set env vars in your shell or use a .env loader (do NOT commit .env to git):

  $env:MEILISEARCH_HOST = 'https://meili.local'
  $env:MEILISEARCH_API_KEY = 'the-admin-key'
  $env:MEILISEARCH_SEARCH_KEY = 'the-search-key'

Notes about meilisearch_api_key in existing code
- The `meilisearch_api_key` you saw referenced in some configs was intended to be the admin key for the Worker. Do not use it directly in client code. Instead:
  - Worker uses MEILISEARCH_API_KEY (admin) and MEILISEARCH_SEARCH_KEY (search).
  - Clients must call the Worker and authenticate using service JWTs or end-user JWTs; they should never hold MEILISEARCH_API_KEY.
