# Enhanced Meilisearch Gateway - API Documentation

## Overview
The enhanced gateway now provides **comprehensive API functionality** while forwarding all operations to Railway Meilisearch. This gives you the best of both worlds:

- **Gateway Worker**: Authentication, user isolation, business logic
- **Railway Meilisearch**: Search engine, data storage, indexing

## Architecture Benefits

### ✅ What the Enhanced Gateway Provides:
1. **JWT Authentication** - Validates user tokens
2. **User Isolation** - Automatic `userId` filtering on all operations  
3. **Document Ownership Security** - Users can only access their own documents
4. **Full CRUD API** - Complete document management
5. **Railway Delegation** - All search operations forwarded to Railway Meilisearch
6. **Index Configuration** - Setup and manage search settings

### ✅ API Endpoints:

#### Public Endpoints (No Auth Required)
- `GET /health` - Gateway and Meilisearch health status
- `POST /setup` - Configure Railway Meilisearch index settings

#### Authenticated Endpoints (JWT Required)
- `GET /search?q=query&limit=20&offset=0&filter=...` - Search with user isolation
- `POST /search` - Search with JSON payload (user isolation applied)
- `POST /documents` - Add/update documents (userId automatically set)
- `DELETE /documents` - Delete documents (ownership verification)

## Key Security Features

### User Isolation
```typescript
// All search requests automatically get user filtering:
const userFilter = `userId = "${userId}"`;
const combinedFilter = userFilter + " AND " + customFilter;
```

### Document Ownership
```typescript
// Documents are always tagged with authenticated user:
const userDocuments = documents.map(doc => ({
  ...doc,
  userId: userId // Override any provided userId - SECURITY
}));
```

### Deletion Safety
```typescript
// Users can only delete their own documents:
// 1. Verify ownership via search
// 2. Delete only owned documents
// 3. Return task status
```

## Deployment Status

**Current Issue**: Route conflict preventing deployment
- The route `search.tamyla.com/*` is assigned to `meilisearch-gateway` 
- Need to unassign/delete the old worker to deploy enhanced version

**Next Steps**:
1. Go to Cloudflare Dashboard: https://dash.cloudflare.com/0506015145cda87c34f9ab8e9675a8a9/workers/overview
2. Delete or unassign the route from `meilisearch-gateway`
3. Run: `npx wrangler deploy --env production` from gateway directory

## Testing Commands (After Deployment)

```bash
# Health check
curl https://search.tamyla.com/health

# Search (requires valid JWT)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     "https://search.tamyla.com/search?q=test&limit=5"

# Add documents (requires valid JWT)
curl -X POST https://search.tamyla.com/documents \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '[{"id":"doc1","title":"Test","summary":"Test doc","entities":[],"topics":[],"filename":"test.txt","mimeType":"text/plain","uploadedAt":"2025-08-24T17:00:00Z","lastAnalyzed":"2025-08-24T17:00:00Z"}]'
```

## What Makes This Better Than Separate Workers

Instead of having:
- `meilisearch-integration` (full business logic)
- `meilisearch-gateway` (simple proxy)
- Confusion about which to use

You now have:
- **One comprehensive gateway** that provides full API + forwards to Railway
- **Clear separation**: Gateway = API layer, Railway = Search engine
- **Better security**: Centralized auth and user isolation
- **Easier maintenance**: Single worker to manage
