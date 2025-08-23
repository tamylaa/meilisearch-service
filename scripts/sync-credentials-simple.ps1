# sync-credentials-simple.ps1
# Simple script to sync Meilisearch credentials to Cloudflare Workers

param(
    [string]$Environment = "production"
)

Set-StrictMode -Version Latest

try {
    Write-Host "=== Meilisearch Credential Sync ===" -ForegroundColor Cyan
    
    # Get current Railway variables
    Write-Host "Getting Meilisearch credentials from Railway..." -ForegroundColor Yellow
    $vars = & npx railway variables -s meilisearch-service --json | ConvertFrom-Json
    
    $masterKey = $vars.MEILI_MASTER_KEY
    $searchKey = $vars.MEILI_SEARCH_KEY
    
    if (-not $masterKey) {
        Write-Host "ERROR: MEILI_MASTER_KEY not found in Railway" -ForegroundColor Red
        exit 1
    }
    
    if (-not $searchKey) {
        Write-Host "ERROR: MEILI_SEARCH_KEY not found in Railway" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Found Master Key: $($masterKey.Substring(0,8))..." -ForegroundColor Green
    Write-Host "Found Search Key: $($searchKey.Substring(0,8))..." -ForegroundColor Green
    
    # Navigate to content-skimmer
    $originalLocation = Get-Location
    Set-Location "..\content-skimmer"
    
    Write-Host "Setting Cloudflare Worker secrets..." -ForegroundColor Yellow
    
    # Set the search key as MEILISEARCH_API_KEY (matches content-skimmer interface)
    Write-Host "Setting MEILISEARCH_API_KEY..."
    echo $searchKey | npx wrangler secret put MEILISEARCH_API_KEY --env $Environment
    
    Write-Host "Setting MEILI_MASTER_KEY..."
    echo $masterKey | npx wrangler secret put MEILI_MASTER_KEY --env $Environment
    
    Set-Location $originalLocation
    
    Write-Host "`n✅ Credentials synchronized successfully!" -ForegroundColor Green
    Write-Host "Next: Deploy content-skimmer with: cd content-skimmer; npx wrangler deploy --env $Environment" -ForegroundColor Cyan
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
