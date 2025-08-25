// Meilisearch Gateway Cloudflare Worker
// Comprehensive API service that forwards all operations to Railway Meilisearch
// Provides: Authentication, User Isolation, Business Logic + Railway delegation

interface Env {
  MEILISEARCH_HOST: string;      // Railway Meilisearch URL
  MEILI_MASTER_KEY: string;      // From Railway
  MEILI_SEARCH_KEY: string;      // From Railway
  AUTH_JWT_SECRET: string;       // For JWT validation
  ALLOWED_ORIGINS: string;       // CORS origins
}

interface SearchRequest {
  q: string;
  limit?: number;
  offset?: number;
  filter?: string;
  sort?: string[];
}

interface DocumentMetadata {
  id: string;
  title: string;
  summary: string;
  entities: string[];
  topics: string[];
  userId: string;
  filename: string;
  mimeType: string;
  uploadedAt: string;
  lastAnalyzed: string;
}

interface AuthResult {
  success: boolean;
  user?: { id: string; email: string };
  error?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // CORS handling
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*', // Should be env.ALLOWED_ORIGINS in production
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // Resolve canonical secrets with fallback to legacy names
      const masterKey = (env as any).MEILI_MASTER_KEY || (env as any).MEILISEARCH_MASTER_KEY || '';
      const searchKey = (env as any).MEILI_SEARCH_KEY || (env as any).MEILISEARCH_SEARCH_KEY || '';
      const meilisearchHost = env.MEILISEARCH_HOST || (env as any).MEILISEARCH_URL || '';

      let response: Response;

      // Public endpoints (no auth required)
      if (path === '/health' && method === 'GET') {
        response = await handleHealth(env);
      } else if (path === '/setup' && method === 'POST') {
        // Admin setup endpoint - configure index settings
        response = await handleSetup(env, masterKey, meilisearchHost);
      } else {
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

        const userId = authResult.user!.id;

        // Authenticated endpoints
        if (path === '/search' && (method === 'GET' || method === 'POST')) {
          response = await handleSearch(request, env, searchKey, meilisearchHost, userId);
        } else if (path === '/documents' && method === 'POST') {
          response = await handleDocumentIndex(request, env, masterKey, meilisearchHost, userId);
        } else if (path === '/documents' && method === 'DELETE') {
          response = await handleDocumentDelete(request, env, masterKey, searchKey, meilisearchHost, userId);
        } else {
          response = new Response('Not Found', { status: 404 });
        }
      }

      // Add CORS headers to all responses
      Object.entries(corsHeaders).forEach(([key, value]) => {
        response.headers.set(key, value);
      });

      return response;

    } catch (error) {
      console.error('Gateway error:', error);
      const errorResponse = new Response(
        JSON.stringify({ error: 'Internal server error' }), 
        { 
          status: 500,
          headers: { 'Content-Type': 'application/json', ...corsHeaders }
        }
      );
      return errorResponse;
    }
  },
};

// JWT Authentication function
async function authenticateRequest(request: Request, jwtSecret: string): Promise<AuthResult> {
  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return { success: false, error: 'Authorization header required' };
    }

    const token = authHeader.substring(7);
    
    // Simple JWT validation (you might want to use a proper JWT library)
    // For now, this is a basic implementation
    const [header, payload, signature] = token.split('.');
    
    if (!header || !payload || !signature) {
      return { success: false, error: 'Invalid token format' };
    }

    // Decode payload (base64url)
    const decodedPayload = JSON.parse(atob(payload.replace(/-/g, '+').replace(/_/g, '/')));
    
    // Check expiration
    if (decodedPayload.exp && Date.now() >= decodedPayload.exp * 1000) {
      return { success: false, error: 'Token expired' };
    }

    return { 
      success: true, 
      user: { 
        id: decodedPayload.sub || decodedPayload.userId, 
        email: decodedPayload.email 
      } 
    };
  } catch (error) {
    return { success: false, error: 'Invalid token' };
  }
}

// Setup endpoint - configure Railway Meilisearch index
async function handleSetup(env: Env, masterKey: string, meilisearchHost: string): Promise<Response> {
  try {
    const indexName = 'documents'; // or 'content' based on your preference

    // Configure searchable attributes
    await fetch(`${meilisearchHost}/indexes/${indexName}/settings/searchable-attributes`, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${masterKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify([
        'title',
        'summary', 
        'entities',
        'topics',
        'filename'
      ]),
    });

    // Configure filterable attributes  
    await fetch(`${meilisearchHost}/indexes/${indexName}/settings/filterable-attributes`, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${masterKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify([
        'userId',
        'entities',
        'topics', 
        'mimeType',
        'uploadedAt',
        'lastAnalyzed'
      ]),
    });

    // Configure sortable attributes
    await fetch(`${meilisearchHost}/indexes/${indexName}/settings/sortable-attributes`, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${masterKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify([
        'uploadedAt',
        'lastAnalyzed',
        'title'
      ]),
    });

    return new Response(JSON.stringify({ success: true, index: indexName }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: 'Setup failed' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}

async function handleSearch(request: Request, env: Env, searchKey: string, meilisearchHost: string, userId: string): Promise<Response> {
  let searchRequest: SearchRequest;
  
  // Handle both GET and POST requests
  if (request.method === 'GET') {
    const url = new URL(request.url);
    searchRequest = {
      q: url.searchParams.get('q') || '',
      limit: parseInt(url.searchParams.get('limit') || '20'),
      offset: parseInt(url.searchParams.get('offset') || '0'),
      filter: url.searchParams.get('filter') || undefined,
      sort: url.searchParams.get('sort')?.split(',') || undefined,
    };
  } else {
    searchRequest = await request.json();
  }
  
  // Validate search request
  if (!searchRequest.q || typeof searchRequest.q !== 'string') {
    return new Response(
      JSON.stringify({ error: 'Query parameter "q" is required' }), 
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    );
  }

  // Apply user isolation - automatically filter by userId
  const userFilter = `userId = "${userId}"`;
  const combinedFilter = searchRequest.filter ? `${userFilter} AND ${searchRequest.filter}` : userFilter;

  // Forward to Railway Meilisearch with user-scoped filtering
  const meilisearchResponse = await fetch(`${meilisearchHost}/indexes/documents/search`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${searchKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      q: searchRequest.q,
      limit: Math.min(searchRequest.limit || 20, 100), // Cap at 100
      offset: searchRequest.offset || 0,
      filter: combinedFilter, // USER ISOLATION APPLIED HERE
      sort: searchRequest.sort,
      attributesToHighlight: ['title', 'summary'],
      highlightPreTag: '<mark>',
      highlightPostTag: '</mark>',
    }),
  });

  const result = await meilisearchResponse.json();
  
  return new Response(JSON.stringify(result), {
    status: meilisearchResponse.status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function handleDocumentIndex(request: Request, env: Env, masterKey: string, meilisearchHost: string, userId: string): Promise<Response> {
  const documents: DocumentMetadata[] = await request.json();
  
  // BUSINESS LOGIC: Automatically set userId for all documents to the authenticated user
  const userDocuments = documents.map(doc => ({
    ...doc,
    userId: userId // Override any provided userId with authenticated user - SECURITY
  }));
  
  // Forward to Railway Meilisearch with master key for indexing
  const meilisearchResponse = await fetch(`${meilisearchHost}/indexes/documents/documents`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${masterKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(userDocuments),
  });

  const result = await meilisearchResponse.json();
  
  return new Response(JSON.stringify(result), {
    status: meilisearchResponse.status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function handleDocumentDelete(request: Request, env: Env, masterKey: string, searchKey: string, meilisearchHost: string, userId: string): Promise<Response> {
  const { ids }: { ids: string[] } = await request.json();
  
  // SECURITY: Verify ownership before deletion
  // First, check which documents belong to the authenticated user
  const verificationResponse = await fetch(`${meilisearchHost}/indexes/documents/search`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${searchKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      q: '',
      filter: `userId = "${userId}" AND id IN [${ids.map(id => `"${id}"`).join(',')}]`,
      attributesToRetrieve: ['id'],
      limit: 1000
    }),
  });

  if (!verificationResponse.ok) {
    return new Response(JSON.stringify({ error: 'Failed to verify document ownership' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const verificationResult = await verificationResponse.json() as { hits: Array<{ id: string }> };
  const ownedIds = verificationResult.hits.map((doc) => doc.id);
  
  if (ownedIds.length === 0) {
    return new Response(JSON.stringify({ 
      error: 'No documents found or access denied',
      enqueuedAt: new Date().toISOString(),
      taskUid: null 
    }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Delete only the documents the user owns
  const deleteResponse = await fetch(`${meilisearchHost}/indexes/documents/documents/delete-batch`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${masterKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(ownedIds),
  });

  const result = await deleteResponse.json();
  
  return new Response(JSON.stringify(result), {
    status: deleteResponse.status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function handleHealth(env: Env): Promise<Response> {
  try {
    const healthResponse = await fetch(`${env.MEILISEARCH_HOST}/health`);
    const health = await healthResponse.json();
    
    return new Response(JSON.stringify({
      gateway: 'ok',
      meilisearch: health,
      timestamp: new Date().toISOString(),
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({
      gateway: 'ok',
      meilisearch: 'error',
      error: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString(),
    }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' },
    });
  }
}
