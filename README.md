# Meilisearch Integration for Content Skimmer

A Cloudflare Worker that provides secure, scalable, and modular Meilisearch integration for the Content Skimmer project. This worker acts as a bridge between your D1 database and Meilisearch, providing fast search capabilities with proper access control and data synchronization.

## Features

- **Cloudflare Worker Architecture**: Serverless, edge-deployed search service
- **Secure API Access**: API key and JWT-based authentication with row-level security
- **D1 Integration**: Seamless sync with D1 database for metadata and results
- **Full-text Search**: Advanced search with filters, facets, and highlighting
- **Auto-sync**: Event-driven synchronization between D1 and Meilisearch
- **Production Ready**: Monitoring, backup, and scaling guidance included

## Quick Start

### 1. Deploy the Worker
```bash
# Install dependencies
npm install

# Set up environment variables
wrangler secret put MEILISEARCH_HOST
wrangler secret put MEILISEARCH_API_KEY  
wrangler secret put MEILISEARCH_SEARCH_KEY

# Deploy to production
npm run deploy
```

### 2. Initialize Search Index
```bash
curl -X POST 'https://your-worker.workers.dev/setup'
```

### 3. Start Searching
```bash
curl 'https://your-worker.workers.dev/search?q=your-query&filter=userId="user-123"'
```

## API Endpoints

| Endpoint | Method | Description |
|----------|---------|-------------|
| `/setup` | POST | Initialize search index and settings |
| `/search` | GET | Search documents with filters and facets |
| `/documents` | POST | Add or update documents in search index |
| `/documents` | DELETE | Remove documents from search index |
| `/health` | GET | Health check and status |

## Project Structure

```
meilisearch-integration/
├── src/
│   └── index.ts           # Main Cloudflare Worker code
├── docs/
│   ├── deployment-guide.md     # Meilisearch deployment options
│   ├── integration-examples.md # Code samples and usage
│   └── d1-requirements.md      # D1 database requirements
├── wrangler.toml          # Cloudflare Worker configuration
├── package.json           # Dependencies and scripts
└── tsconfig.json          # TypeScript configuration
```

## Configuration

### Environment Variables (Cloudflare Secrets)
- `MEILISEARCH_HOST`: Your Meilisearch endpoint URL
- `MEILISEARCH_API_KEY`: Master key for admin operations
- `MEILISEARCH_SEARCH_KEY`: Read-only key for search operations

### Optional D1 Binding
```toml
# Add to wrangler.toml if using D1 integration
[[d1_databases]]
binding = "DB"
database_name = "content-skimmer-db"
database_id = "your-d1-database-id"
```

## Usage Examples

### Search with Filters
```javascript
const response = await fetch('https://your-worker.workers.dev/search?' + 
  new URLSearchParams({
    q: 'quarterly report',
    filter: 'userId = "user-123" AND topics = "business"',
    facets: 'entities,topics,mimeType'
  })
);
const results = await response.json();
```

### Add Documents
```javascript
const documents = [{
  id: 'doc-123',
  title: 'Sample Document',
  summary: 'Document summary...',
  entities: ['person:John Doe'],
  topics: ['business'],
  userId: 'user-123',
  filename: 'document.pdf',
  mimeType: 'application/pdf',
  uploadedAt: '2024-08-22T10:00:00Z',
  lastAnalyzed: '2024-08-22T10:05:00Z'
}];

await fetch('https://your-worker.workers.dev/documents', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(documents)
});
```

## Documentation

- **[Deployment Guide](docs/deployment-guide.md)**: Complete setup instructions for Meilisearch Cloud and self-hosted options
- **[Integration Examples](docs/integration-examples.md)**: Code samples for D1 sync, search queries, and error handling  
- **[D1 Requirements](docs/d1-requirements.md)**: Database schema and API requirements for the data service

## Security Features

- **Row-level Security**: Users can only search their own documents
- **API Key Management**: Separate keys for admin and search operations
- **Rate Limiting**: Built-in protection against abuse
- **CORS Support**: Configurable cross-origin access
- **Network Restrictions**: Support for IP allowlists

## Monitoring

The worker includes built-in health checks and error logging. Monitor these metrics:
- Search response times
- Index sync success rates  
- API usage and rate limits
- Error rates and types

## Scaling

- **Serverless**: Automatic scaling with Cloudflare Workers
- **Edge Caching**: Search results cached at edge locations
- **Meilisearch Scaling**: Vertical scaling recommendations in deployment guide
- **Batch Processing**: Efficient bulk operations for large datasets

## Contributing

1. Make changes to the TypeScript source in `src/`
2. Test locally with `npm run dev`
3. Update documentation in `docs/` as needed
4. Deploy with `npm run deploy`

## License

This project is part of the Content Skimmer system and follows the same license terms.
