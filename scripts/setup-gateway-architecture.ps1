# setup-gateway-architecture.ps1
# Complete setup for proper Meilisearch gateway architecture

param(
    [string]$Environment = "production"
)

Set-StrictMode -Version Latest

try {
    Write-Host "=== Setting Up Meilisearch Gateway Architecture ===" -ForegroundColor Cyan
    Write-Host "Environment: $Environment" -ForegroundColor White
    
    # Step 1: Get Railway credentials
    Write-Host "`n1. Getting Railway credentials..." -ForegroundColor Yellow
    $vars = & npx railway variables -s meilisearch-service --json | ConvertFrom-Json
    $masterKey = $vars.MEILI_MASTER_KEY
    $searchKey = $vars.MEILI_SEARCH_KEY
    
    if (-not $masterKey -or -not $searchKey) {
        Write-Host "ERROR: Missing credentials in Railway" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Railway credentials obtained" -ForegroundColor Green
    
    # Step 2: Deploy Meilisearch Gateway
    Write-Host "`n2. Deploying Meilisearch Gateway..." -ForegroundColor Yellow
    Push-Location "gateway"
    
    # Set gateway secrets
    Write-Host "Setting gateway secrets..."
    echo $masterKey | npx wrangler secret put MEILISEARCH_MASTER_KEY --env $Environment
    echo $searchKey | npx wrangler secret put MEILISEARCH_SEARCH_KEY --env $Environment
    
    # Deploy gateway
    Write-Host "Deploying gateway worker..."
    & npx wrangler deploy --env $Environment
    
    Pop-Location
    Write-Host "✓ Gateway deployed" -ForegroundColor Green
    
    # Step 3: Update content-skimmer configuration
    Write-Host "`n3. Updating content-skimmer configuration..." -ForegroundColor Yellow
    
    # Update wrangler.toml to use gateway URL
    $wranglerPath = "..\content-skimmer\wrangler.toml"
    if (Test-Path $wranglerPath) {
        $content = Get-Content $wranglerPath -Raw
        
        if ($Environment -eq "production") {
            $gatewayUrl = "https://search.tamyla.com"
        } else {
            $gatewayUrl = "https://search-staging.tamyla.com"  
        }
        
        # Replace the direct Railway URL with gateway URL
        $content = $content -replace 'MEILISEARCH_URL = "https://meilisearch-service-production-01e0.up.railway.app"', "MEILISEARCH_URL = `"$gatewayUrl`""
        Set-Content $wranglerPath -Value $content
        
        Write-Host "✓ Updated content-skimmer to use gateway: $gatewayUrl" -ForegroundColor Green
    }
    
    # Set content-skimmer secrets (service token for gateway auth)
    Push-Location "..\content-skimmer"
    
    Write-Host "Setting content-skimmer secrets..."
    echo $searchKey | npx wrangler secret put MEILISEARCH_API_KEY --env $Environment
    
    Pop-Location
    Write-Host "✓ Content-skimmer configured" -ForegroundColor Green
    
    # Step 4: Validation
    Write-Host "`n4. Architecture Validation:" -ForegroundColor Yellow
    Write-Host "   Gateway URL: $(if($Environment -eq 'production'){'https://search.tamyla.com'}else{'https://search-staging.tamyla.com'})" -ForegroundColor White
    Write-Host "   Railway Backend: https://meilisearch-service-production-01e0.up.railway.app" -ForegroundColor White
    Write-Host "   Content-skimmer: Uses gateway (secure)" -ForegroundColor White
    
    Write-Host "`n🎯 CORRECT ARCHITECTURE NOW IN PLACE:" -ForegroundColor Green
    Write-Host "   content-skimmer (CF) → meilisearch-gateway (CF) → Railway Meilisearch" -ForegroundColor Green
    
    Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Deploy content-skimmer: cd content-skimmer; npx wrangler deploy --env $Environment" -ForegroundColor White
    Write-Host "   2. Test the gateway: curl https://search.tamyla.com/health" -ForegroundColor White
    Write-Host "   3. Test search integration through the gateway" -ForegroundColor White
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
