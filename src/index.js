import { MeiliSearch } from 'meilisearch';
import { authenticateRequest } from './auth.js';
class MeilisearchService {
    client;
    searchClient;
    documentsIndex;
    constructor(env) {
        // Admin client for write operations
        this.client = new MeiliSearch({
            host: env.MEILISEARCH_HOST,
            apiKey: env.MEILI_MASTER_KEY,
        });
        // Search client for read operations
        this.searchClient = new MeiliSearch({
            host: env.MEILISEARCH_HOST,
            apiKey: env.MEILI_SEARCH_KEY,
        });
        this.documentsIndex = this.client.index('documents');
    }
    async addOrUpdateDocuments(docs) {
        return this.documentsIndex.addDocuments(docs, { primaryKey: 'id' });
    }
    async deleteDocuments(ids, userId) {
        // For security, only allow deletion of documents owned by the authenticated user
        // First, verify ownership by checking if documents belong to user
        const searchIndex = this.searchClient.index('documents');
        const ownedDocs = await searchIndex.search('', {
            filter: `userId = "${userId}" AND id IN [${ids.map(id => `"${id}"`).join(',')}]`,
            attributesToRetrieve: ['id']
        });
        const ownedIds = ownedDocs.hits.map((doc) => doc.id);
        if (ownedIds.length > 0) {
            return this.documentsIndex.deleteDocuments(ownedIds);
        }
        return { enqueuedAt: new Date().toISOString(), taskUid: null };
    }
    async searchDocuments(query, userId, filters, facets) {
        const searchIndex = this.searchClient.index('documents');
        // Automatically apply user isolation
        const userFilter = `userId = "${userId}"`;
        const combinedFilter = filters ? `${userFilter} AND ${filters}` : userFilter;
        return searchIndex.search(query, {
            filter: combinedFilter,
            facets: facets,
            attributesToHighlight: ['title', 'summary'],
            highlightPreTag: '<mark>',
            highlightPostTag: '</mark>'
        });
    }
    async setupIndex() {
        // Configure searchable attributes
        await this.documentsIndex.updateSearchableAttributes([
            'title',
            'summary',
            'entities',
            'topics',
            'filename'
        ]);
        // Configure filterable attributes
        await this.documentsIndex.updateFilterableAttributes([
            'userId',
            'entities',
            'topics',
            'mimeType',
            'uploadedAt',
            'lastAnalyzed'
        ]);
        // Configure sortable attributes
        await this.documentsIndex.updateSortableAttributes([
            'uploadedAt',
            'lastAnalyzed',
            'title'
        ]);
        return { success: true };
    }
}
export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);
        const path = url.pathname;
        const method = request.method;
        // CORS headers for browser requests
        const corsHeaders = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        };
        if (method === 'OPTIONS') {
            return new Response(null, { headers: corsHeaders });
        }
        try {
            const meilisearch = new MeilisearchService(env);
            // Setup endpoint (admin only) - no auth required for initial setup
            if (path === '/setup' && method === 'POST') {
                const result = await meilisearch.setupIndex();
                return new Response(JSON.stringify(result), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                });
            }
            // Health check - no auth required
            if (path === '/health' && method === 'GET') {
                return new Response(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                });
            }
            // All other endpoints require authentication
            const authResult = await authenticateRequest(request, env.AUTH_JWT_SECRET);
            if (!authResult.success) {
                return new Response(JSON.stringify({
                    error: authResult.error,
                    code: 'UNAUTHORIZED'
                }), {
                    status: 401,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                });
            }
            const userId = authResult.user.id;
            // Search endpoint - with user isolation
            if (path === '/search' && method === 'GET') {
                const query = url.searchParams.get('q') || '';
                const filters = url.searchParams.get('filter') || undefined;
                const facets = url.searchParams.get('facets')?.split(',') || undefined;
                const results = await meilisearch.searchDocuments(query, userId, filters, facets);
                return new Response(JSON.stringify(results), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                });
            }
            // Add/Update documents endpoint - ensure userId is set
            if (path === '/documents' && method === 'POST') {
                const documents = await request.json();
                // Automatically set userId for all documents to the authenticated user
                const userDocuments = documents.map(doc => ({
                    ...doc,
                    userId: userId // Override any provided userId with authenticated user
                }));
                const result = await meilisearch.addOrUpdateDocuments(userDocuments);
                return new Response(JSON.stringify(result), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                });
            }
            // Delete documents endpoint - with user isolation
            if (path === '/documents' && method === 'DELETE') {
                const { ids } = await request.json();
                const result = await meilisearch.deleteDocuments(ids, userId);
                return new Response(JSON.stringify(result), {
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                });
            }
            return new Response('Not Found', {
                status: 404,
                headers: corsHeaders
            });
        }
        catch (error) {
            console.error('Error:', error);
            return new Response(JSON.stringify({ error: error.message }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }
    },
};
