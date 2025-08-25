#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fix Cloudflare route assignments to deploy the enhanced gateway
.DESCRIPTION
    This script helps resolve route conflicts preventing deployment of the enhanced meilisearch gateway
#>

param(
    [string]$AccountId = "0506015145cda87c34f9ab8e9675a8a9",
    [string]$ZoneName = "tamyla.com",
    [string]$RoutePattern = "search.tamyla.com/*"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "🔧 Cloudflare Route Cleanup for Meilisearch Gateway" -ForegroundColor Cyan
Write-Host "Account ID: $AccountId" -ForegroundColor Yellow
Write-Host "Zone: $ZoneName" -ForegroundColor Yellow
Write-Host "Route: $RoutePattern" -ForegroundColor Yellow
Write-Host ""

# Step 1: Get auth token from wrangler
Write-Host "1. Getting Cloudflare API token..." -ForegroundColor Green
try {
    $wranglerOutput = npx wrangler whoami 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get Wrangler auth info"
    }
    Write-Host "✅ Authenticated with Cloudflare" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to authenticate with Cloudflare" -ForegroundColor Red
    Write-Host "Please run: npx wrangler login" -ForegroundColor Yellow
    exit 1
}

# Step 2: Manual steps for route cleanup
Write-Host ""
Write-Host "2. Route Cleanup Required" -ForegroundColor Green
Write-Host "The route $RoutePattern is currently assigned to 'meilisearch-gateway'." -ForegroundColor Yellow
Write-Host "To fix this, you need to:"
Write-Host ""
Write-Host "Option A - Cloudflare Dashboard (Recommended):" -ForegroundColor Cyan
Write-Host "1. Go to: https://dash.cloudflare.com/$AccountId/workers/overview"
Write-Host "2. Find the 'meilisearch-gateway' worker"
Write-Host "3. Click on it, go to 'Routes' tab"
Write-Host "4. Remove the route: $RoutePattern"
Write-Host "5. Then run: npx wrangler deploy --env production"
Write-Host ""
Write-Host "Option B - Delete the old worker entirely:" -ForegroundColor Cyan
Write-Host "1. Go to the same dashboard URL above"
Write-Host "2. Find 'meilisearch-gateway' worker" 
Write-Host "3. Click Delete (this will free up the route)"
Write-Host "4. Then run: npx wrangler deploy --env production"
Write-Host ""

# Step 3: Verification commands
Write-Host "3. After fixing the route, verify with these commands:" -ForegroundColor Green
Write-Host ""
Write-Host "Test health endpoint:" -ForegroundColor Cyan
Write-Host "curl https://search.tamyla.com/health"
Write-Host ""
Write-Host "Test search (requires JWT token):" -ForegroundColor Cyan
Write-Host "curl -H `"Authorization: Bearer YOUR_JWT_TOKEN`" `"https://search.tamyla.com/search?q=test`&limit=5`""
Write-Host ""

Write-Host "🎯 Once deployed, the enhanced gateway will provide:" -ForegroundColor Magenta
Write-Host "  ✅ JWT Authentication" 
Write-Host "  ✅ User Isolation (automatic userId filtering)"
Write-Host "  ✅ Document Ownership Security"
Write-Host "  ✅ Full CRUD operations forwarded to Railway Meilisearch"
Write-Host "  ✅ /setup endpoint for index configuration"
Write-Host ""

Write-Host "Press any key to open the Cloudflare dashboard..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Start-Process "https://dash.cloudflare.com/$AccountId/workers/overview"
