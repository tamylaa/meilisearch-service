# Meilisearch Integration Examples

This document provides practical examples for integrating the Meilisearch Cloudflare Worker with your Content Skimmer system.

## Worker Deployment

### Deploy the Worker
```bash
# Install dependencies
npm install

# Deploy to staging
npm run deploy -- --env staging

# Deploy to production  
npm run deploy -- --env production
```

### Set Environment Variables
```bash
# Set Meilisearch credentials
wrangler secret put MEILISEARCH_HOST --env production
wrangler secret put MEILISEARCH_API_KEY --env production
wrangler secret put MEILISEARCH_SEARCH_KEY --env production
```

## API Usage Examples

### 1. Initialize Search Index
```javascript
// Setup the search index (run once)
const response = await fetch('https://your-worker.workers.dev/setup', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  }
});

const result = await response.json();
console.log('Index setup:', result);
```

### 2. Add Documents to Search Index
```javascript
// Sync documents from D1 to Meilisearch
const documents = [
  {
    id: 'doc-123',
    title: 'Sample Document',
    summary: 'This is a sample document for testing search functionality.',
    entities: ['person:John Doe', 'company:Acme Corp'],
    topics: ['business', 'technology'],
    userId: 'user-456',
    filename: 'sample.pdf',
    mimeType: 'application/pdf',
    uploadedAt: '2024-08-22T10:00:00Z',
    lastAnalyzed: '2024-08-22T10:05:00Z'
  }
];

const response = await fetch('https://your-worker.workers.dev/documents', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(documents)
});

const result = await response.json();
console.log('Documents added:', result);
```

### 3. Search Documents
```javascript
// Basic search
const searchResponse = await fetch(
  'https://your-worker.workers.dev/search?q=technology'
);
const searchResults = await searchResponse.json();

// Advanced search with filters
const advancedSearch = await fetch(
  'https://your-worker.workers.dev/search?' + new URLSearchParams({
    q: 'business',
    filter: 'userId = "user-456" AND topics = "technology"',
    facets: 'entities,topics,mimeType'
  })
);
const advancedResults = await advancedSearch.json();

console.log('Search results:', advancedResults);
```

### 4. Delete Documents
```javascript
// Remove documents from search index
const deleteResponse = await fetch('https://your-worker.workers.dev/documents', {
  method: 'DELETE',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    ids: ['doc-123', 'doc-456']
  })
});

const deleteResult = await deleteResponse.json();
console.log('Documents deleted:', deleteResult);
```

## Integration with Content Skimmer Worker

### Sync After Document Analysis
```javascript
// In your content analysis worker
export default {
  async fetch(request, env, ctx) {
    // ... existing content analysis logic ...
    
    // After analysis is complete, sync to search
    await syncToMeilisearch(analyzedDocument, env);
    
    return response;
  }
};

async function syncToMeilisearch(document, env) {
  const searchDocument = {
    id: document.id,
    title: document.title,
    summary: document.summary,
    entities: document.entities || [],
    topics: document.topics || [],
    userId: document.userId,
    filename: document.filename,
    mimeType: document.mimeType,
    uploadedAt: document.uploadedAt,
    lastAnalyzed: new Date().toISOString()
  };

  try {
    const response = await fetch(`${env.MEILISEARCH_WORKER_URL}/documents`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify([searchDocument])
    });

    if (!response.ok) {
      console.error('Failed to sync to Meilisearch:', await response.text());
    }
  } catch (error) {
    console.error('Meilisearch sync error:', error);
  }
}
```

### Search Integration in Frontend
```javascript
// Frontend search component
class DocumentSearch {
  constructor(workerUrl) {
    this.workerUrl = workerUrl;
  }

  async search(query, userId, filters = {}) {
    const params = new URLSearchParams({
      q: query,
      filter: this.buildFilter(userId, filters),
      facets: 'entities,topics,mimeType'
    });

    const response = await fetch(`${this.workerUrl}/search?${params}`);
    return response.json();
  }

  buildFilter(userId, filters) {
    let filterParts = [`userId = "${userId}"`];

    if (filters.topics?.length) {
      const topicFilter = filters.topics.map(t => `topics = "${t}"`).join(' OR ');
      filterParts.push(`(${topicFilter})`);
    }

    if (filters.entities?.length) {
      const entityFilter = filters.entities.map(e => `entities = "${e}"`).join(' OR ');
      filterParts.push(`(${entityFilter})`);
    }

    if (filters.mimeType) {
      filterParts.push(`mimeType = "${filters.mimeType}"`);
    }

    if (filters.dateRange) {
      filterParts.push(`uploadedAt >= ${filters.dateRange.start} AND uploadedAt <= ${filters.dateRange.end}`);
    }

    return filterParts.join(' AND ');
  }
}

// Usage example
const search = new DocumentSearch('https://your-worker.workers.dev');

const results = await search.search('quarterly report', 'user-123', {
  topics: ['business', 'finance'],
  mimeType: 'application/pdf',
  dateRange: {
    start: '2024-01-01T00:00:00Z',
    end: '2024-12-31T23:59:59Z'
  }
});
```

## D1 Integration Examples

### Sync New Documents
```javascript
// Function to sync newly analyzed documents
async function syncNewDocumentsToSearch(env) {
  // Get unsynced documents from D1
  const { results } = await env.DB.prepare(`
    SELECT * FROM documents 
    WHERE searchIndexed = 0 
    ORDER BY lastAnalyzed DESC 
    LIMIT 100
  `).all();

  if (results.length === 0) return;

  // Format for Meilisearch
  const searchDocs = results.map(doc => ({
    id: doc.id,
    title: doc.title,
    summary: doc.summary,
    entities: JSON.parse(doc.entities || '[]'),
    topics: JSON.parse(doc.topics || '[]'),
    userId: doc.userId,
    filename: doc.filename,
    mimeType: doc.mimeType,
    uploadedAt: doc.uploadedAt,
    lastAnalyzed: doc.lastAnalyzed
  }));

  // Send to Meilisearch
  const response = await fetch(`${env.MEILISEARCH_WORKER_URL}/documents`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(searchDocs)
  });

  if (response.ok) {
    // Mark as synced in D1
    const docIds = results.map(doc => doc.id);
    await env.DB.prepare(`
      UPDATE documents 
      SET searchIndexed = 1, searchIndexedAt = ?
      WHERE id IN (${docIds.map(() => '?').join(',')})
    `).bind(new Date().toISOString(), ...docIds).run();

    console.log(`Synced ${results.length} documents to Meilisearch`);
  }
}
```

### Handle Document Deletions
```javascript
// Function to sync deletions
async function syncDeletedDocuments(env) {
  // Get recently deleted document IDs (you'd implement this based on your deletion strategy)
  const deletedIds = await getDeletedDocumentIds(env);

  if (deletedIds.length === 0) return;

  // Remove from Meilisearch
  const response = await fetch(`${env.MEILISEARCH_WORKER_URL}/documents`, {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ids: deletedIds })
  });

  if (response.ok) {
    console.log(`Removed ${deletedIds.length} documents from search index`);
  }
}
```

## Scheduled Sync Worker

```javascript
// scheduled-sync.js - Deploy as a separate scheduled worker
export default {
  async scheduled(event, env, ctx) {
    console.log('Starting scheduled Meilisearch sync');

    try {
      // Sync new/updated documents
      await syncNewDocumentsToSearch(env);
      
      // Handle deletions
      await syncDeletedDocuments(env);
      
      // Health check
      const healthResponse = await fetch(`${env.MEILISEARCH_WORKER_URL}/health`);
      const health = await healthResponse.json();
      
      console.log('Sync completed successfully', health);
      
    } catch (error) {
      console.error('Sync failed:', error);
      // Could send to error tracking service
    }
  }
};
```

## Error Handling and Retry Logic

```javascript
// Robust sync function with retries
async function syncWithRetry(documents, workerUrl, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(`${workerUrl}/documents`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(documents)
      });

      if (response.ok) {
        return await response.json();
      }

      if (response.status >= 400 && response.status < 500) {
        // Client error, don't retry
        throw new Error(`Client error: ${response.status}`);
      }

      if (attempt === maxRetries) {
        throw new Error(`Server error after ${maxRetries} attempts: ${response.status}`);
      }

      // Wait before retry (exponential backoff)
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));

    } catch (error) {
      if (attempt === maxRetries) {
        throw error;
      }
      console.warn(`Sync attempt ${attempt} failed:`, error.message);
    }
  }
}
```

## Testing

### Unit Tests
```javascript
// test/search.test.js
import { MeilisearchService } from '../src/index.js';

const mockEnv = {
  MEILISEARCH_HOST: 'http://localhost:7700',
  MEILISEARCH_API_KEY: 'test-key',
  MEILISEARCH_SEARCH_KEY: 'search-key'
};

describe('MeilisearchService', () => {
  let service;

  beforeEach(() => {
    service = new MeilisearchService(mockEnv);
  });

  test('should search documents', async () => {
    const results = await service.searchDocuments('test query');
    expect(results).toBeDefined();
    expect(results.hits).toBeInstanceOf(Array);
  });

  test('should handle filters correctly', async () => {
    const results = await service.searchDocuments(
      'test', 
      'userId = "user-123"'
    );
    expect(results).toBeDefined();
  });
});
```

### Integration Tests
```javascript
// test/integration.test.js
describe('Meilisearch Integration', () => {
  test('should sync document from D1 to Meilisearch', async () => {
    // Create test document in D1
    const testDoc = {
      id: 'test-doc-123',
      title: 'Test Document',
      summary: 'Test summary',
      // ... other fields
    };

    // Trigger sync
    await syncDocumentToMeilisearch(testDoc);

    // Verify document is searchable
    const searchResults = await searchDocuments('Test Document');
    expect(searchResults.hits).toHaveLength(1);
    expect(searchResults.hits[0].id).toBe('test-doc-123');
  });
});
```

This completes the Meilisearch integration setup as a Cloudflare Worker with comprehensive examples, D1 integration patterns, and deployment guides.
