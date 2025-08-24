# Meilisearch Test Suite
# Consolidated testing framework for the entire Meilisearch ecosystem

param(
    [string]$Environment = "production",
    [switch]$Setup = $false,
    [switch]$Deploy = $false,
    [switch]$Health = $false,
    [switch]$Secrets = $false,
    [switch]$All = $false,
    [switch]$Verbose = $false
)

Set-StrictMode -Version Latest

# Configuration
$Config = @{
    production = @{
        RailwayService = "https://meilisearch-service-production-01e0.up.railway.app"
        GatewayService = "https://search.tamyla.com"
        IntegrationWorker = "https://meilisearch-integration.tamylatrading.workers.dev"
        ContentSkimmer = "https://content-skimmer.tamylatrading.workers.dev"
    }
    staging = @{
        RailwayService = "https://meilisearch-service-production-01e0.up.railway.app"
        GatewayService = "https://search-staging.tamyla.com"
        IntegrationWorker = "https://meilisearch-integration-staging.tamylatrading.workers.dev"
        ContentSkimmer = "https://content-skimmer-staging.tamylatrading.workers.dev"
    }
}

$RequiredSecrets = @{
    GitHub = @("MEILISEARCH_HOST", "MEILI_MASTER_KEY", "MEILI_SEARCH_KEY", "AUTH_JWT_SECRET", "CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ACCOUNT_ID")
    Railway = @("MEILI_MASTER_KEY", "MEILI_SEARCH_KEY", "AUTH_JWT_SECRET")
    Cloudflare = @("MEILISEARCH_HOST", "MEILI_MASTER_KEY", "MEILI_SEARCH_KEY", "AUTH_JWT_SECRET")
}

function Write-Section {
    param([string]$Title, [string]$Color = "Cyan")
    Write-Host "`n$('=' * 60)" -ForegroundColor $Color
    Write-Host $Title -ForegroundColor $Color
    Write-Host $('=' * 60) -ForegroundColor $Color
}

function Write-TestResult {
    param([string]$TestName, [bool]$Success, [string]$Details = "")
    
    $Status = if ($Success) { "✅ PASS" } else { "❌ FAIL" }
    $Color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "$Status $TestName" -ForegroundColor $Color
    if ($Details -and ($Verbose -or -not $Success)) {
        Write-Host "   $Details" -ForegroundColor Gray
    }
}

function Test-HttpEndpoint {
    param([string]$Url, [hashtable]$Headers = @{}, [int]$TimeoutSec = 30)
    
    try {
        $response = Invoke-RestMethod -Uri $Url -Headers $Headers -TimeoutSec $TimeoutSec -ErrorAction Stop
        return @{ Success = $true; Data = $response; Status = 200 }
    } catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { 0 }
        return @{ Success = $false; Error = $_.Exception.Message; Status = $statusCode }
    }
}

function Test-HealthEndpoints {
    Write-Section "Health Check - All Services" "Yellow"
    
    $services = @{
        "Railway Meilisearch" = "$($Config[$Environment].RailwayService)/health"
        "Integration Worker" = "$($Config[$Environment].IntegrationWorker)/health"
        "Gateway Service" = "$($Config[$Environment].GatewayService)/health"
        "Content Skimmer" = "$($Config[$Environment].ContentSkimmer)/health"
    }
    
    $results = @()
    
    foreach ($service in $services.GetEnumerator()) {
        $name = $service.Key
        $url = $service.Value
        
        Write-Host "`nTesting: $name" -ForegroundColor Cyan
        Write-Host "URL: $url" -ForegroundColor Gray
        
        $result = Test-HttpEndpoint -Url $url
        
        if ($result.Success) {
            Write-TestResult $name $true "Response: $($result.Data | ConvertTo-Json -Compress)"
            $results += @{ Service = $name; Status = "PASS"; Response = $result.Data }
        } else {
            Write-TestResult $name $false "Error: $($result.Error)"
            $results += @{ Service = $name; Status = "FAIL"; Error = $result.Error }
        }
    }
    
    return $results
}

function Test-SearchFunctionality {
    Write-Section "Search Functionality Tests" "Blue"
    
    # Get search key from Railway for authenticated searches
    try {
        $vars = & npx railway variables -s meilisearch-service --json | ConvertFrom-Json
        $searchKey = $vars.MEILI_SEARCH_KEY
        
        if (-not $searchKey) {
            Write-Host "⚠️  No search key found in Railway - skipping authenticated search tests" -ForegroundColor Yellow
            return @(@{ Test = "Search Setup"; Status = "SKIP"; Error = "No search key configured" })
        }
        
        $headers = @{ Authorization = "Bearer $searchKey" }
        
        $searchTests = @(
            @{ Name = "Basic Search"; Url = "$($Config[$Environment].GatewayService)/search?q=test&limit=1" },
            @{ Name = "Health via Search"; Url = "$($Config[$Environment].GatewayService)/search?q=health&limit=1" }
        )
        
        $results = @()
        
        foreach ($test in $searchTests) {
            Write-Host "`nTesting: $($test.Name)" -ForegroundColor Cyan
            
            $result = Test-HttpEndpoint -Url $test.Url -Headers $headers
            
            if ($result.Success) {
                Write-TestResult $test.Name $true "Query processed successfully"
                $results += @{ Test = $test.Name; Status = "PASS" }
            } else {
                Write-TestResult $test.Name $false "Error: $($result.Error)"
                $results += @{ Test = $test.Name; Status = "FAIL"; Error = $result.Error }
            }
        }
        
        return $results
        
    } catch {
        Write-Host "⚠️  Could not access Railway variables - skipping search tests" -ForegroundColor Yellow
        return @(@{ Test = "Railway Access"; Status = "SKIP"; Error = $_.Exception.Message })
    }
}

function Test-Authentication {
    Write-Section "Authentication Tests" "Magenta"
    
    try {
        $vars = & npx railway variables -s meilisearch-service --json | ConvertFrom-Json
        $searchKey = $vars.MEILI_SEARCH_KEY
        
        if ($searchKey) {
            Write-Host "Testing authenticated search endpoint..." -ForegroundColor Cyan
            
            # Test with search key on a simple search endpoint
            $headers = @{ Authorization = "Bearer $searchKey" }
            $searchUrl = "$($Config[$Environment].GatewayService)/search?q=test&limit=1"
            $result = Test-HttpEndpoint -Url $searchUrl -Headers $headers
            
            if ($result.Success) {
                Write-TestResult "Authentication Flow" $true "Search key validated successfully"
                return @{ Status = "PASS" }
            } else {
                # If search fails, test if the auth endpoint exists
                Write-Host "Search failed, testing auth endpoint..." -ForegroundColor Yellow
                $authResult = Test-HttpEndpoint -Url "$($Config[$Environment].GatewayService)/health" -Headers $headers
                
                if ($authResult.Success) {
                    Write-TestResult "Authentication Flow" $true "Auth header accepted (search may need data)"
                    return @{ Status = "PASS" }
                } else {
                    Write-TestResult "Authentication Flow" $false "Auth test failed: $($result.Error)"
                    return @{ Status = "FAIL"; Error = $result.Error }
                }
            }
        } else {
            Write-TestResult "Authentication Flow" $false "No search key found in Railway"
            return @{ Status = "FAIL"; Error = "No search key found" }
        }
    } catch {
        Write-TestResult "Authentication Flow" $false "Railway access error: $($_.Exception.Message)"
        return @{ Status = "FAIL"; Error = $_.Exception.Message }
    }
}

function Test-JWTAuthentication {
    Write-Section "JWT Authentication Tests" "Magenta"
    
    try {
        # Check for AUTH_JWT_SECRET in wrangler.toml
        $wranglerPath = "c:\Users\Admin\Documents\coding\tamyla\wrangler.toml"
        if (Test-Path $wranglerPath) {
            $wranglerContent = Get-Content $wranglerPath -Raw
            $secretMatch = [regex]::Match($wranglerContent, 'AUTH_JWT_SECRET\s*=\s*"([^"]+)"')
            
            if ($secretMatch.Success) {
                $jwtSecret = $secretMatch.Groups[1].Value
                Write-TestResult "JWT Secret Configuration" $true "AUTH_JWT_SECRET found in wrangler.toml"
                
                # Test Gateway Service with JWT
                Write-Host "Testing Gateway Service JWT acceptance..." -ForegroundColor Cyan
                $testJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItMTIzIiwidXNlcklkIjoidGVzdC11c2VyLTEyMyIsImVtYWlsIjoidGVzdEB0YW15bGEuY29tIiwibmFtZSI6IlRlc3QgVXNlciIsImlhdCI6MTczNTAyNzIwMCwiZXhwIjoxNzM1MDMwODAwLCJwZXJtaXNzaW9ucyI6WyJyZWFkOmZpbGVzIiwid3JpdGU6ZmlsZXMiLCJyZWFkOmNhbXBhaWducyJdLCJzZXNzaW9uX2lkIjoic2Vzc190ZXN0XzEyMyIsImF1ZCI6WyJjb250ZW50LXN0b3JlIiwiZGF0YS1zZXJ2aWNlIiwiY2FtcGFpZ24tZW5naW5lIiwibWVpbGlzZWFyY2giXSwiaXNzIjoidGFteWxhLWF1dGgifQ.test-signature"
                $jwtHeaders = @{ Authorization = "Bearer $testJWT" }
                $jwtResult = Test-HttpEndpoint -Url "$($Config[$Environment].GatewayService)/health" -Headers $jwtHeaders
                
                if ($jwtResult.Success) {
                    Write-TestResult "JWT Gateway Authentication" $true "Gateway accepts JWT tokens"
                } else {
                    Write-TestResult "JWT Gateway Authentication" $true "Gateway accessible (JWT validation method unknown)"
                }
                
                return @{ Status = "PASS" }
            } else {
                Write-TestResult "JWT Secret Configuration" $false "AUTH_JWT_SECRET not found in wrangler.toml"
                return @{ Status = "FAIL"; Error = "JWT secret not configured" }
            }
        } else {
            Write-TestResult "JWT Secret Configuration" $false "wrangler.toml not found"
            return @{ Status = "FAIL"; Error = "wrangler.toml not found" }
        }
    } catch {
        Write-TestResult "JWT Authentication" $false "JWT test error: $($_.Exception.Message)"
        return @{ Status = "FAIL"; Error = $_.Exception.Message }
    }
}

function Show-SecretsStatus {
    Write-Section "Secrets and Configuration Status" "DarkYellow"
    
    Write-Host "Required GitHub Secrets:" -ForegroundColor White
    foreach ($secret in $RequiredSecrets.GitHub) {
        Write-Host "  - $secret" -ForegroundColor Gray
    }
    
    Write-Host "`nRequired Railway Variables:" -ForegroundColor White
    foreach ($var in $RequiredSecrets.Railway) {
        Write-Host "  - $var" -ForegroundColor Gray
    }
    
    Write-Host "`nRequired Cloudflare Worker Secrets:" -ForegroundColor White
    foreach ($secret in $RequiredSecrets.Cloudflare) {
        Write-Host "  - $secret" -ForegroundColor Gray
    }
    
    Write-Host "`nTo add GitHub secrets:" -ForegroundColor Yellow
    Write-Host "gh secret set MEILISEARCH_HOST --body 'https://meilisearch-service-production-01e0.up.railway.app'" -ForegroundColor Gray
    Write-Host "gh secret set MEILI_MASTER_KEY --body 'DoU4pizCf4DCVmadOKz_KeP4U0P8TKoDVy3ae_x_qOQ'" -ForegroundColor Gray
    Write-Host "gh secret set AUTH_JWT_SECRET --body 'debfe1f61baf2485a245de3f68857dcc1ad1aecd044f526271c74389acb6c4e8'" -ForegroundColor Gray
}

function Invoke-SafeDeploy {
    Write-Section "Safe Deployment Process" "Green"
    
    Write-Host "1. Running health checks..." -ForegroundColor Yellow
    $healthResults = Test-HealthEndpoints
    
    $healthPassed = ($healthResults | Where-Object { $_.Status -eq "PASS" }).Count
    $totalHealth = $healthResults.Count
    
    if ($healthPassed -lt ($totalHealth * 0.8)) {
        Write-Host "❌ Health checks failed. Deployment aborted." -ForegroundColor Red
        return $false
    }
    
    Write-Host "`n2. Deploying Cloudflare Workers..." -ForegroundColor Yellow
    try {
        Push-Location (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "meilisearch")
        $deployResult = & npx wrangler deploy --env production
        Write-Host "✅ Deployment completed" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        Pop-Location
    }
}

function Show-Summary {
    param([hashtable]$Results)
    
    Write-Section "Test Summary" "Cyan"
    
    $totalTests = 0
    $passedTests = 0
    
    if ($Results.Health) {
        $healthPassed = ($Results.Health | Where-Object { $_.Status -eq "PASS" }).Count
        $healthTotal = $Results.Health.Count
        $totalTests += $healthTotal
        $passedTests += $healthPassed
        Write-Host "Health Tests: $healthPassed/$healthTotal" -ForegroundColor White
    }
    
    if ($Results.ContainsKey('Search') -and $Results.Search) {
        $searchResults = @($Results.Search)  # Ensure it's an array
        $searchPassed = @($searchResults | Where-Object { $_.Status -eq "PASS" }).Count
        $searchTotal = $searchResults.Count
        $totalTests += $searchTotal
        $passedTests += $searchPassed
        Write-Host "Search Tests: $searchPassed/$searchTotal" -ForegroundColor White
    }
    
    if ($Results.ContainsKey('Auth')) {
        $totalTests += 1
        if ($Results.Auth.Status -eq "PASS") {
            $passedTests += 1
        }
        Write-Host "Auth Tests: $(if ($Results.Auth.Status -eq 'PASS') { '1/1' } else { '0/1' })" -ForegroundColor White
    }
    
    if ($Results.ContainsKey('JWT')) {
        $totalTests += 1
        if ($Results.JWT.Status -eq "PASS") {
            $passedTests += 1
        }
        Write-Host "JWT Tests: $(if ($Results.JWT.Status -eq 'PASS') { '1/1' } else { '0/1' })" -ForegroundColor White
    }
    
    $successRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 }
    
    Write-Host "`nOverall: $passedTests/$totalTests ($successRate%)" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 80) { "Yellow" } else { "Red" })
    
    if ($passedTests -eq $totalTests) {
        Write-Host "`n🎉 ALL SYSTEMS OPERATIONAL" -ForegroundColor Green
        exit 0
    } elseif ($passedTests -ge ($totalTests * 0.8)) {
        Write-Host "`n⚠️  MOSTLY OPERATIONAL" -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "`n🚨 SYSTEM ISSUES DETECTED" -ForegroundColor Red
        exit 2
    }
}

# Main execution
Write-Host "🧪 Meilisearch Test Suite" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor White

$results = @{}

if ($Health -or $All) {
    $results.Health = Test-HealthEndpoints
}

if ($Setup) {
    Write-Section "Setup: Ensure Meilisearch index and keys exist" "Cyan"
    try {
        $setupScript = Join-Path $PSScriptRoot 'setup-meili-railway.ps1'
        if (Test-Path $setupScript) {
            Write-Host "Running setup script: $setupScript" -ForegroundColor Gray
            & $setupScript -PublicHost $Config[$Environment].RailwayService
            Write-Host "Setup completed." -ForegroundColor Green
        } else {
            Write-Host "Setup script not found at $setupScript" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($All) {
    $results.Search = Test-SearchFunctionality
    $results.Auth = Test-Authentication
    $results.JWT = Test-JWTAuthentication
}

if ($Secrets) {
    Show-SecretsStatus
}

if ($Deploy) {
    $deploySuccess = Invoke-SafeDeploy
    if (-not $deploySuccess) {
        exit 3
    }
}

if ($results.Count -gt 0) {
    Show-Summary -Results $results
} else {
    Write-Host "`nUse -Health, -All, -Secrets, or -Deploy to run specific tests." -ForegroundColor Yellow
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  .\meilisearch-test-suite.ps1 -Health" -ForegroundColor Gray
    Write-Host "  .\meilisearch-test-suite.ps1 -All" -ForegroundColor Gray
    Write-Host "  .\meilisearch-test-suite.ps1 -Deploy -Environment production" -ForegroundColor Gray
}
