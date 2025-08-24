# URL Health Checker
# Quick script to test which URLs are working or failing

$URLs = @{
    "Railway Meilisearch" = "https://meilisearch-service-production-01e0.up.railway.app/health"
    "Meilisearch Integration (workers.dev)" = "https://meilisearch-integration.tamylatrading.workers.dev/health"
    "Custom Domain (future)" = "https://search.tamyla.com/health"
    "Content Skimmer" = "https://content-skimmer.tamylatrading.workers.dev/health"
}

Write-Host "Testing URL Availability..." -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

foreach ($service in $URLs.GetEnumerator()) {
    $name = $service.Key
    $url = $service.Value
    
    try {
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 10 -ErrorAction Stop
        Write-Host "✅ $name" -ForegroundColor Green
        Write-Host "   URL: $url" -ForegroundColor Gray
        Write-Host "   Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
    } catch {
        $errorMsg = $_.Exception.Message
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode } else { "No Response" }
        
        Write-Host "❌ $name" -ForegroundColor Red
        Write-Host "   URL: $url" -ForegroundColor Gray
        Write-Host "   Error: $errorMsg" -ForegroundColor Red
        Write-Host "   Status: $statusCode" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "URL Test Complete" -ForegroundColor Cyan
