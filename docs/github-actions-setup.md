# GitHub Actions Deployment Setup

## Required GitHub Secrets

To enable automated deployment, you need to set the following secrets in your GitHub repository:

### 1. Navigate to Repository Settings
Go to: `https://github.com/tamylaa/meilisearch-service/settings/secrets/actions`

### 2. Add Repository Secrets

#### **Cloudflare Secrets**
```
CLOUDFLARE_API_TOKEN     - Your Cloudflare API token with Workers:Edit permissions
CLOUDFLARE_ACCOUNT_ID    - Your Cloudflare Account ID
```

#### **Meilisearch Secrets**
```
MEILISEARCH_HOST         - Your Meilisearch server URL (e.g., https://your-meilisearch.com)
MEILISEARCH_API_KEY      - Your Meilisearch admin/write API key
MEILISEARCH_SEARCH_KEY   - Your Meilisearch search-only API key
```

#### **Authentication Secret**
```
AUTH_JWT_SECRET          - JWT secret key (same as used in other Tamyla services)
```

### 3. Environment Setup

The workflow includes two environments:
- **staging** - Deploys automatically on push to main/master
- **production** - Deploys after staging success, can include manual approval

### 4. How to Get Cloudflare Credentials

#### API Token:
1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token"
3. Use "Edit Cloudflare Workers" template
4. Scope to your account and zone
5. Copy the generated token

#### Account ID:
1. Go to https://dash.cloudflare.com
2. Select your domain
3. Copy Account ID from the right sidebar

### 5. Workflow Triggers

The deployment will trigger on:
- ✅ Push to `main` or `master` branch
- ✅ Pull requests (test only, no deployment)
- ✅ Manual trigger via GitHub Actions UI

### 6. Deployment Process

```
Code Push → Test (TypeScript build) → Deploy Staging → Deploy Production
```

### 7. Manual Deployment

You can also deploy manually using:
```bash
npm run deploy:staging
npm run deploy:production
```

### 8. Monitoring

Check deployment status at:
`https://github.com/tamylaa/meilisearch-service/actions`
