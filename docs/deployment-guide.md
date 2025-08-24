# Meilisearch Deployment Guide

This guide covers deploying Meilisearch for the Content Skimmer project with security, scalability, and operational best practices.

## Deployment Options

### Option 1: Meilisearch Cloud (Recommended)
Meilisearch Cloud provides managed hosting with built-in security, monitoring, and scaling.

**Pros:**
- Fully managed service
- Built-in security and compliance
- Automatic scaling and backups
- Professional support

**Cons:**
- Monthly cost
- Less control over infrastructure

**Setup:**
1. Sign up at https://cloud.meilisearch.com
2. Create a new project
3. Note the endpoint URL and API keys
4. Configure network restrictions (if available)

### Option 2: Self-Hosted on Cloud Provider

#### Docker on Cloud VM
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Create Meilisearch data directory
mkdir -p /opt/meilisearch/data

# Run Meilisearch with Docker
docker run -d \
  --name meilisearch \
  -p 7700:7700 \
  -v /opt/meilisearch/data:/meili_data \
  -e MEILI_MASTER_KEY="your-secure-master-key-32-chars-min" \
  -e MEILI_ENV="production" \
  -e MEILI_HTTP_ADDR="0.0.0.0:7700" \
  --restart unless-stopped \
  getmeili/meilisearch:v1.9
```

#### Docker Compose (Production)
```yaml
# docker-compose.yml
version: '3.8'
services:
  meilisearch:
    image: getmeili/meilisearch:v1.9
    container_name: meilisearch
    restart: unless-stopped
    ports:
      - "7700:7700"
    environment:
      - MEILI_MASTER_KEY=${MEILI_MASTER_KEY}
      - MEILI_ENV=production
      - MEILI_HTTP_ADDR=0.0.0.0:7700
      - MEILI_NO_ANALYTICS=true
    volumes:
      - ./meili_data:/meili_data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7700/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:alpine
    container_name: meilisearch-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - meilisearch
```

## Security Configuration

### API Keys
Generate secure API keys with appropriate permissions:

```bash
# Generate master key (32+ characters)
openssl rand -base64 32

# In production, use environment variables
export MEILI_MASTER_KEY="your-generated-master-key"
```

### Network Security

#### Firewall Rules
```bash
# Allow only specific IPs/ranges
ufw allow from YOUR_CLOUDFLARE_IP_RANGE to any port 7700
ufw allow from YOUR_ADMIN_IP to any port 7700
ufw deny 7700
```

#### Nginx Reverse Proxy
```nginx
# nginx.conf
server {
    listen 443 ssl http2;
    server_name your-meilisearch-domain.com;
    
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=search:10m rate=10r/s;
    limit_req zone=search burst=20 nodelay;
    
    # IP allowlist
    allow YOUR_CLOUDFLARE_IP_RANGE;
    deny all;
    
    location / {
        proxy_pass http://localhost:7700;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Security headers
        add_header X-Content-Type-Options nosniff;
        add_header X-Frame-Options DENY;
        add_header X-XSS-Protection "1; mode=block";
    }
}
```

### Key Management

#### Generate API Keys
```javascript
// Generate keys with specific permissions
const masterKey = process.env.MEILI_MASTER_KEY;
const client = new MeiliSearch({
  host: 'https://your-meilisearch-endpoint',
  apiKey: masterKey
});

// Search-only key
const searchKey = await client.generateTenantToken({
  searchRules: {
    '*': {
      filter: 'userId = "{{user_id}}"'  // Row-level security
    }
  },
  apiKeyUid: 'search-key-uid',
  expiresAt: new Date('2025-12-31')
});

// Admin key for indexing
const adminKey = await client.generateTenantToken({
  searchRules: { '*': {} },
  apiKeyUid: 'admin-key-uid',
  expiresAt: new Date('2025-12-31')
});
```

## Environment Configuration

### Cloudflare Worker Secrets
```bash
# Set secrets in Cloudflare Workers
wrangler secret put MEILISEARCH_HOST
wrangler secret put MEILI_MASTER_KEY
wrangler secret put MEILI_SEARCH_KEY
```

### Environment Variables
```bash
# .env.production
MEILI_MASTER_KEY=your-secure-master-key-here
MEILI_ENV=production
MEILI_HTTP_ADDR=0.0.0.0:7700
MEILI_NO_ANALYTICS=true
MEILI_MAX_INDEXING_MEMORY=2147483648  # 2GB
MEILI_MAX_INDEXING_THREADS=4
```

## Monitoring and Health Checks

### Health Check Endpoint
```bash
curl -X GET 'https://your-meilisearch-endpoint/health'
```

### Monitoring Script
```javascript
// monitoring.js - Deploy as scheduled Cloudflare Worker
export default {
  async scheduled(event, env, ctx) {
    try {
      const response = await fetch(`${env.MEILISEARCH_HOST}/health`);
      const health = await response.json();
      
      if (!response.ok) {
        // Send alert to monitoring service
        await sendAlert('Meilisearch health check failed', health);
      }
      
      // Log metrics
      console.log('Meilisearch health:', health);
      
    } catch (error) {
      await sendAlert('Meilisearch unreachable', error.message);
    }
  }
};
```

### Metrics to Monitor
- Response time
- Index size and document count
- Memory and CPU usage
- API key usage and rate limits
- Search query performance

## Backup and Recovery

### Data Backup
```bash
# Create backup
curl -X POST 'https://your-meilisearch-endpoint/dumps' \
  -H 'Authorization: Bearer your-master-key'

# Download backup
curl -X GET 'https://your-meilisearch-endpoint/dumps/dump-id/status' \
  -H 'Authorization: Bearer your-master-key'
```

### Automated Backup Script
```bash
#!/bin/bash
# backup-meilisearch.sh
MEILI_HOST="https://your-meilisearch-endpoint"
MEILI_KEY="your-master-key"
BACKUP_DIR="/opt/backups/meilisearch"

# Create dump
DUMP_ID=$(curl -s -X POST "$MEILI_HOST/dumps" \
  -H "Authorization: Bearer $MEILI_KEY" | jq -r '.taskUid')

# Wait for completion and download
echo "Backup created with ID: $DUMP_ID"
# Add logic to check status and download when ready
```

## Scaling Considerations

### Vertical Scaling
- Start with 2GB RAM, 2 vCPUs
- Monitor memory usage during indexing
- Scale up based on index size and query volume

### Horizontal Scaling
- Meilisearch doesn't support clustering
- Use load balancer with read replicas for high availability
- Consider sharding by user ID for very large datasets

### Performance Optimization
```javascript
// Index settings for optimal performance
await index.updateSettings({
  searchableAttributes: ['title', 'summary', 'entities', 'topics'],
  filterableAttributes: ['userId', 'entities', 'topics', 'mimeType'],
  sortableAttributes: ['uploadedAt', 'lastAnalyzed'],
  rankingRules: [
    'words',
    'typo',
    'proximity',
    'attribute',
    'sort',
    'exactness'
  ],
  typoTolerance: {
    enabled: true,
    minWordSizeForTypos: {
      oneTypo: 4,
      twoTypos: 8
    }
  }
});
```

## Cost Optimization

### Index Size Management
- Regular cleanup of old documents
- Compress large text fields
- Use appropriate data types

### Query Optimization
- Implement caching layer
- Optimize search attributes
- Use pagination for large result sets

## Production Checklist

- [ ] Secure master key generated and stored
- [ ] API keys configured with appropriate permissions
- [ ] Network access restricted to trusted sources
- [ ] HTTPS/TLS configured
- [ ] Rate limiting implemented
- [ ] Monitoring and alerting set up
- [ ] Backup strategy implemented
- [ ] Log aggregation configured
- [ ] Performance testing completed
- [ ] Disaster recovery plan documented
