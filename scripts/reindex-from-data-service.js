/*
 Simple reconciliation/reindex script for Meilisearch.
 It fetches canonical metadata from the data-service (assumes a read-only API exists)
 and POSTs documents to the Meilisearch Worker `/documents` endpoint.

 Usage (locally):
   node scripts/reindex-from-data-service.js --data-url http://localhost:3000/files --worker-url https://meili.example.workers.dev --token <SERVICE_JWT>

 The script is intentionally minimal and should be run from a trusted environment.
*/

const fetch = require('node-fetch');
const { URL } = require('url');

async function main() {
  const argv = require('minimist')(process.argv.slice(2));
  const dataUrl = argv['data-url'] || process.env.DATA_SERVICE_URL;
  const workerUrl = argv['worker-url'] || process.env.MEILI_WORKER_URL;
  const token = argv['token'] || process.env.SERVICE_JWT;

  if (!dataUrl || !workerUrl) {
    console.error('Missing required parameters: --data-url and --worker-url (or env DATA_SERVICE_URL / MEILI_WORKER_URL)');
    process.exit(2);
  }

  console.log('Fetching canonical metadata from', dataUrl);
  const res = await fetch(dataUrl, { headers: { 'Accept': 'application/json' } });
  if (!res.ok) {
    console.error('Failed to fetch data service:', res.status, res.statusText);
    process.exit(3);
  }

  const items = await res.json();
  console.log('Found', items.length, 'items');

  for (const item of items) {
    // Map to DocumentMetadata expected by worker
    const doc = {
      id: item.fileId || item.id,
      title: item.title || item.filename,
      summary: item.summary || item.metadata?.summary || '',
      entities: item.entities || [],
      topics: item.topics || [],
      userId: item.userId,
      filename: item.filename,
      mimeType: item.mimeType,
      uploadedAt: item.uploadedAt,
      lastAnalyzed: item.lastAnalyzed || new Date().toISOString(),
    };

    const response = await fetch(`${workerUrl.replace(/\/$/, '')}/documents`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { 'Authorization': `Bearer ${token}` } : {})
      },
      body: JSON.stringify([doc])
    });

    if (!response.ok) {
      console.error('Failed to index', doc.id, response.status, response.statusText);
    } else {
      console.log('Indexed', doc.id);
    }
  }
}

main().catch(err => { console.error(err); process.exit(1); });
