// Meilisearch Gateway Cloudflare Worker
// This acts as a secure proxy between content-skimmer and Railway Meilisearch

interface Env {
  MEILISEARCH_HOST: string;      // Railway Meilisearch URL
  MEILI_MASTER_KEY: string; // From Railway
  MEILI_SEARCH_KEY: string; // From Railway
  ALLOWED_ORIGINS: string;      // CORS origins
}

interface SearchRequest {
  q: string;
  limit?: number;
  offset?: number;
  filter?: string;
  sort?: string[];
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // CORS handling
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*', // Should be env.ALLOWED_ORIGINS in production
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
  // Resolve canonical secrets with fallback to legacy names (safe compatibility layer)
  // This allows us to roll out canonical names (MEILI_*) without immediately deleting
  // existing legacy secrets (MEILISEARCH_*).
  const masterKey = (env as any).MEILI_MASTER_KEY || (env as any).MEILISEARCH_MASTER_KEY || '';
  const searchKey = (env as any).MEILI_SEARCH_KEY || (env as any).MEILISEARCH_SEARCH_KEY || '';

      let response: Response;

      // Route requests  
      if ((path === '/search' && method === 'POST') || (path === '/search' && method === 'GET')) {
        // pass resolved keys via a small wrapper object so handlers can use canonical names
        const handlerEnv = Object.assign({}, env, { MEILI_MASTER_KEY: masterKey, MEILI_SEARCH_KEY: searchKey });
        response = await handleSearch(request, handlerEnv as Env);
      } else if (path === '/documents' && method === 'POST') {
        const handlerEnv = Object.assign({}, env, { MEILI_MASTER_KEY: masterKey, MEILI_SEARCH_KEY: searchKey });
        response = await handleDocumentIndex(request, handlerEnv as Env);
      } else if (path === '/documents' && method === 'DELETE') {
        const handlerEnv = Object.assign({}, env, { MEILI_MASTER_KEY: masterKey, MEILI_SEARCH_KEY: searchKey });
        response = await handleDocumentDelete(request, handlerEnv as Env);
      } else if (path === '/health') {
        response = await handleHealth(env);
      } else {
        response = new Response('Not Found', { status: 404 });
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

async function handleSearch(request: Request, env: Env): Promise<Response> {
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

  // Forward to Meilisearch with search key
  const meilisearchResponse = await fetch(`${env.MEILISEARCH_HOST}/indexes/content/search`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.MEILI_SEARCH_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      q: searchRequest.q,
      limit: Math.min(searchRequest.limit || 20, 100), // Cap at 100
      offset: searchRequest.offset || 0,
      filter: searchRequest.filter,
      sort: searchRequest.sort,
    }),
  });

  const result = await meilisearchResponse.json();
  
  return new Response(JSON.stringify(result), {
    status: meilisearchResponse.status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function handleDocumentIndex(request: Request, env: Env): Promise<Response> {
  // Verify authorization (you should implement proper auth here)
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return new Response(
      JSON.stringify({ error: 'Authorization required' }), 
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }

  const documents = await request.json();
  
  // Forward to Meilisearch with master key for indexing
  const meilisearchResponse = await fetch(`${env.MEILISEARCH_HOST}/indexes/content/documents`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.MEILI_MASTER_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(documents),
  });

  const result = await meilisearchResponse.json();
  
  return new Response(JSON.stringify(result), {
    status: meilisearchResponse.status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function handleDocumentDelete(request: Request, env: Env): Promise<Response> {
  // Verify authorization
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return new Response(
      JSON.stringify({ error: 'Authorization required' }), 
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    );
  }

  let documentIds: string[] = [];
  
  // Handle different delete request formats
  const url = new URL(request.url);
  const idParam = url.searchParams.get('id');
  
  if (idParam) {
    // Single document ID from query parameter
    documentIds = [idParam];
  } else {
    // Bulk delete from request body
    try {
      const body = await request.json() as any;
      if (body.ids && Array.isArray(body.ids)) {
        documentIds = body.ids;
      } else if (body.id) {
        documentIds = [body.id];
      } else {
        return new Response(
          JSON.stringify({ error: 'Document ID(s) required' }), 
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        );
      }
    } catch {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON or missing document IDs' }), 
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }
  }

  if (documentIds.length === 0) {
    return new Response(
      JSON.stringify({ error: 'No document IDs provided' }), 
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    );
  }

  // Forward to Meilisearch with master key for deletion
  const meilisearchResponse = await fetch(`${env.MEILISEARCH_HOST}/indexes/content/documents/delete-batch`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.MEILI_MASTER_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(documentIds),
  });

  const result = await meilisearchResponse.text();
  
  return new Response(result, {
    status: meilisearchResponse.status,
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
