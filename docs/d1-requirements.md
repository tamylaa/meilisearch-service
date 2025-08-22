# D1 Requirements for Meilisearch Integration

This document outlines the specific requirements and expectations for the D1 database service to support the Meilisearch integration effectively.

## Data Model Requirements

### Document Metadata Table
The D1 database should maintain a `documents` table with the following structure:

```sql
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  summary TEXT,
  entities TEXT, -- JSON array stored as text
  topics TEXT,   -- JSON array stored as text
  userId TEXT NOT NULL,
  filename TEXT NOT NULL,
  mimeType TEXT NOT NULL,
  uploadedAt TEXT NOT NULL, -- ISO timestamp
  lastAnalyzed TEXT,        -- ISO timestamp
  searchIndexed INTEGER DEFAULT 0, -- Boolean flag for sync status
  searchIndexedAt TEXT,     -- Last indexed timestamp
  FOREIGN KEY (userId) REFERENCES users(id)
);

-- Index for efficient querying
CREATE INDEX idx_documents_user_id ON documents(userId);
CREATE INDEX idx_documents_last_analyzed ON documents(lastAnalyzed);
CREATE INDEX idx_documents_search_indexed ON documents(searchIndexed);
```

## API Requirements

### Data Service Endpoints
The data-service should provide the following endpoints for Meilisearch sync:

#### 1. Get Documents for Indexing
```
GET /documents?searchIndexed=false&limit=100&offset=0
```
- Returns documents that need to be indexed in Meilisearch
- Supports pagination for batch processing
- Filters by searchIndexed flag

#### 2. Mark Documents as Indexed
```
PUT /documents/{id}/search-indexed
```
- Updates the searchIndexed flag and searchIndexedAt timestamp
- Called after successful Meilisearch indexing

#### 3. Get Document Changes
```
GET /documents/changes?since={timestamp}
```
- Returns documents modified since a given timestamp
- Used for incremental sync operations
- Includes deleted document IDs

#### 4. Batch Operations
```
POST /documents/batch-index-status
Body: { "documentIds": ["id1", "id2"], "indexed": true }
```
- Updates multiple documents' search index status in one operation
- Used for efficient batch processing

## Event Triggers

### Database Triggers
D1 should support triggers or hooks for:

1. **Document Insert/Update**: Trigger Meilisearch sync when documents are added or modified
2. **Document Delete**: Trigger Meilisearch document removal
3. **User Delete**: Trigger bulk removal of user's documents from search index

### Event Queue Integration
- D1 operations should optionally emit events to a queue (Cloudflare Queues)
- Events should include document ID, operation type (insert/update/delete), and timestamp
- Meilisearch worker can consume these events for real-time sync

## Data Consistency

### Sync Status Tracking
- Track which documents are successfully indexed in Meilisearch
- Handle partial failures gracefully
- Support retry mechanisms for failed sync operations

### Conflict Resolution
- Handle cases where D1 and Meilisearch data become out of sync
- Provide endpoints for full re-sync operations
- Log sync failures for monitoring

## Security Considerations

### Access Control
- User isolation: Users can only access their own documents
- Admin operations for bulk sync and maintenance
- Audit logging for search operations

### Data Validation
- Validate document metadata before sync
- Sanitize user input to prevent injection attacks
- Enforce schema compliance

## Performance Requirements

### Indexing Performance
- Support batch operations for initial indexing
- Efficient incremental sync for ongoing operations
- Pagination support for large datasets

### Query Optimization
- Indexes on frequently queried fields
- Efficient filtering by user, date ranges, and status
- Connection pooling for high-concurrency scenarios

## Monitoring and Analytics

### Metrics to Track
- Sync success/failure rates
- Time lag between D1 updates and Meilisearch sync
- Document count consistency between systems
- Search query performance and usage patterns

### Health Checks
- Endpoint to verify D1-Meilisearch sync status
- Data consistency validation endpoints
- Performance monitoring integration

## Example Integration Flow

1. **Document Upload**: User uploads document → D1 insert → Event triggered
2. **Content Analysis**: Analysis complete → D1 update → Sync to Meilisearch
3. **Search Query**: User searches → Query Meilisearch → Hydrate results from D1
4. **Document Update**: Content modified → D1 update → Meilisearch re-index
5. **Document Delete**: User deletes → D1 delete → Remove from Meilisearch

This design ensures D1 remains the source of truth while Meilisearch provides fast search capabilities with eventual consistency.
