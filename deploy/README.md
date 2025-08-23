Deploying Meilisearch on Railway (low-cost)

This guide shows how to deploy Meilisearch to Railway using the provided Dockerfile. Railway offers a free tier for small services in many regions — use this to start with minimal cost.

1. Create a new Railway project and add a Docker service.
   - Point Railway to this repository and select the `meilisearch/deploy` folder (or use the public image `getmeili/meilisearch:latest`).

2. Configure environment variables in Railway service settings:
   - `MEILI_MASTER_KEY` — create a strong secret (this is the admin key)

3. Add a persistent volume (recommended) and map to `/data` inside container.

4. Deploy the service.

5. After deployment, note the public host URL (e.g., https://meili-123.up.railway.app). Configure your Worker secrets to point to this host and use the master key.

Security notes:
- Keep `MEILI_MASTER_KEY` secret; Worker should be the only component using it.
- If Railway does not support private network, rely on the admin key placement and short-lived tokens.

Backup and export:
- Use the Meilisearch dump/snapshot endpoints to export indices to object storage. Example:
  curl -X POST 'http://<HOST>:7700/dumps' -H "Authorization: Bearer <MASTER_KEY>"

