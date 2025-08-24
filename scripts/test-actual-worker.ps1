Write-Host "TESTING ACTUAL DEPLOYED WORKER FROM GITHUB ACTIONS" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "GitHub Actions deployed to: meilisearch-integration.tamylatrading.workers.dev" -ForegroundColor Yellow
Write-Host ""

$actualUrls = @(
    "https://meilisearch-integration.tamylatrading.workers.dev/health",
    "https://meilisearch-integration.tamylatrading.workers.dev/",
    "https://meilisearch-integration.tamylatrading.workers.dev"
)

foreach ($url in $actualUrls) {
    Write-Host "Testing: $url" -ForegroundColor Yellow
    try {
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 15 -ErrorAction Stop
        Write-Host "✅ SUCCESS!" -ForegroundColor Green
        Write-Host "Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
    } catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode } else { "No Response" }
        Write-Host "❌ FAILED" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Gray
        Write-Host "Status: $statusCode" -ForegroundColor Gray
    }
    Write-Host ""
}
