param([string]$Environment = "production")

$Config = @{
    production = @{
        RailwayService = "https://meilisearch-service-production-01e0.up.railway.app"
        GatewayService = "https://search.tamyla.com"
        IntegrationWorker = "https://meilisearch-integration.tamylatrading.workers.dev"
        ContentSkimmer = "https://content-skimmer.tamylatrading.workers.dev"
    }
}

function Test-HttpEndpoint {
    param([string]$Url, [int]$TimeoutSec = 15)
    try {
        $response = Invoke-RestMethod -Uri $Url -TimeoutSec $TimeoutSec -ErrorAction Stop
        return @{ Success = $true; Data = $response }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

Write-Host "Quick Health Check - All Meilisearch Services" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Gray

$services = @{
    "Railway Meilisearch" = "$($Config[$Environment].RailwayService)/health"
    "Integration Worker" = "$($Config[$Environment].IntegrationWorker)/health"
    "Gateway Service" = "$($Config[$Environment].GatewayService)/health"
    "Content Skimmer" = "$($Config[$Environment].ContentSkimmer)/health"
}

$passed = 0
$total = $services.Count

foreach ($service in $services.GetEnumerator()) {
    $name = $service.Key
    $url = $service.Value
    
    Write-Host "`nTesting: $name" -ForegroundColor Yellow
    $result = Test-HttpEndpoint -Url $url
    
    if ($result.Success) {
        Write-Host "SUCCESS - HEALTHY" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "FAILED: $($result.Error)" -ForegroundColor Red
    }
}

Write-Host "`n============================================================" -ForegroundColor Gray
Write-Host "Result: $passed/$total services healthy" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })

if ($passed -eq $total) {
    Write-Host "ALL SYSTEMS OPERATIONAL" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some services need attention" -ForegroundColor Yellow
    exit 1
}
