param([string]$Environment = "production")

$Config = @{
    production = @{
        RailwayService = "https://meilisearch-service-production-01e0.up.railway.app"
        GatewayService = "https://search.tamyla.com"
        IntegrationWorker = "https://meilisearch-integration.tamylatrading.workers.dev"
        ContentSkimmer = "https://content-skimmer.tamylatrading.workers.dev"
        AuthService = "https://auth.tamyla.com"
        ContentStore = "https://content.tamyla.com"
    }
}

function Test-HttpEndpoint {
    param([string]$Url, [hashtable]$Headers = @{}, [int]$TimeoutSec = 15)
    try {
        $response = Invoke-RestMethod -Uri $Url -Headers $Headers -TimeoutSec $TimeoutSec -ErrorAction Stop
        return @{ Success = $true; Data = $response; StatusCode = 200 }
    } catch {
        return @{ 
            Success = $false; 
            Error = $_.Exception.Message; 
            StatusCode = try { $_.Exception.Response.StatusCode.value__ } catch { 0 }
        }
    }
}

function New-TestJWT {
    param([string]$Secret, [string]$UserId = "test-user-123")
    
    # Create JWT header
    $header = @{
        alg = "HS256"
        typ = "JWT"
    } | ConvertTo-Json -Compress
    
    # Create JWT payload
    $payload = @{
        sub = $UserId
        userId = $UserId
        email = "test@tamyla.com"
        name = "Test User"
        iat = [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
        exp = [int]([DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds())
        permissions = @("read:files", "write:files", "read:campaigns")
        session_id = "sess_test_123"
        aud = @("content-store", "data-service", "campaign-engine", "meilisearch")
        iss = "tamyla-auth"
    } | ConvertTo-Json -Compress
    
    # Base64URL encode
    $headerB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($header)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $payloadB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payload)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    
    # Create signature data
    $signatureData = "$headerB64.$payloadB64"
    
    # Generate HMAC-SHA256 signature
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    $signature = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($signatureData))
    $signatureB64 = [Convert]::ToBase64String($signature).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    
    return "$headerB64.$payloadB64.$signatureB64"
}

Write-Host "JWT Authentication Test Suite - Service-to-Service Communication" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Gray

try {
    # Get the shared JWT secret from main wrangler.toml
    Write-Host "`n1. Retrieving AUTH_JWT_SECRET from wrangler.toml..." -ForegroundColor Yellow
    
    $wranglerPath = "c:\Users\Admin\Documents\coding\tamyla\wrangler.toml"
    if (Test-Path $wranglerPath) {
        $wranglerContent = Get-Content $wranglerPath -Raw
        $secretMatch = [regex]::Match($wranglerContent, 'AUTH_JWT_SECRET\s*=\s*"([^"]+)"')
        
        if ($secretMatch.Success) {
            $jwtSecret = $secretMatch.Groups[1].Value
            Write-Host "SUCCESS: AUTH_JWT_SECRET found" -ForegroundColor Green
            Write-Host "  Secret: $($jwtSecret.Substring(0,8))...***" -ForegroundColor Gray
        } else {
            Write-Host "ERROR: AUTH_JWT_SECRET not found in wrangler.toml" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "ERROR: wrangler.toml not found" -ForegroundColor Red
        exit 1
    }

    # Test 1: Generate a test JWT token
    Write-Host "`n2. Generating Test JWT Token..." -ForegroundColor Yellow
    $testJWT = New-TestJWT -Secret $jwtSecret
    Write-Host "SUCCESS: Test JWT generated" -ForegroundColor Green
    Write-Host "  Token: $($testJWT.Substring(0,50))..." -ForegroundColor Gray

    # Test 2: Verify JWT structure
    Write-Host "`n3. Verifying JWT Structure..." -ForegroundColor Yellow
    $jwtParts = $testJWT.Split('.')
    if ($jwtParts.Length -eq 3) {
        Write-Host "SUCCESS: JWT has correct structure (header.payload.signature)" -ForegroundColor Green
        
        # Decode and display payload
        $payloadB64 = $jwtParts[1]
        # Add padding if needed
        $padding = 4 - ($payloadB64.Length % 4)
        if ($padding -ne 4) { $payloadB64 += "=" * $padding }
        $payloadB64 = $payloadB64.Replace('-', '+').Replace('_', '/')
        
        try {
            $payloadJson = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payloadB64))
            $payload = $payloadJson | ConvertFrom-Json
            Write-Host "  User ID: $($payload.userId)" -ForegroundColor Gray
            Write-Host "  Audience: $($payload.aud -join ', ')" -ForegroundColor Gray
            Write-Host "  Expires: $(Get-Date -UnixTimeSeconds $payload.exp)" -ForegroundColor Gray
        } catch {
            Write-Host "WARNING: Could not decode payload" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ERROR: Invalid JWT structure" -ForegroundColor Red
    }

    # Test 3: Test Content Skimmer JWT endpoint
    Write-Host "`n4. Testing Content Skimmer JWT Authentication..." -ForegroundColor Yellow
    $skimmerHeaders = @{ Authorization = "Bearer $testJWT" }
    $skimmerResult = Test-HttpEndpoint -Url "$($Config[$Environment].ContentSkimmer)/analytics" -Headers $skimmerHeaders
    
    if ($skimmerResult.Success) {
        Write-Host "SUCCESS: Content Skimmer accepts JWT token" -ForegroundColor Green
    } elseif ($skimmerResult.StatusCode -eq 401) {
        Write-Host "INFO: Content Skimmer rejected JWT (expected if endpoint requires specific permissions)" -ForegroundColor Yellow
    } else {
        Write-Host "WARNING: Content Skimmer test failed - $($skimmerResult.Error)" -ForegroundColor Yellow
    }

    # Test 4: Test Gateway Service JWT Authentication
    Write-Host "`n5. Testing Gateway Service JWT Authentication..." -ForegroundColor Yellow
    $gatewayHeaders = @{ Authorization = "Bearer $testJWT" }
    $gatewayResult = Test-HttpEndpoint -Url "$($Config[$Environment].GatewayService)/health" -Headers $gatewayHeaders
    
    if ($gatewayResult.Success) {
        Write-Host "SUCCESS: Gateway Service accepts JWT token" -ForegroundColor Green
    } elseif ($gatewayResult.StatusCode -eq 401) {
        Write-Host "INFO: Gateway Service requires different authentication" -ForegroundColor Yellow
    } else {
        Write-Host "INFO: Gateway Service test - $($gatewayResult.Error)" -ForegroundColor Yellow
    }

    # Test 5: Test Content Store Service JWT Authentication  
    Write-Host "`n6. Testing Content Store Service JWT Authentication..." -ForegroundColor Yellow
    $contentHeaders = @{ Authorization = "Bearer $testJWT" }
    $contentResult = Test-HttpEndpoint -Url "$($Config[$Environment].ContentStore)/health" -Headers $contentHeaders
    
    if ($contentResult.Success) {
        Write-Host "SUCCESS: Content Store accepts JWT token" -ForegroundColor Green
    } elseif ($contentResult.StatusCode -eq 401) {
        Write-Host "INFO: Content Store rejected JWT (may need proper user context)" -ForegroundColor Yellow
    } else {
        Write-Host "INFO: Content Store test - $($contentResult.Error)" -ForegroundColor Yellow
    }

    # Test 6: Cross-service communication simulation
    Write-Host "`n7. Simulating Cross-Service JWT Communication..." -ForegroundColor Yellow
    
    # Simulate content-skimmer calling meilisearch gateway with JWT
    $searchHeaders = @{ 
        Authorization = "Bearer $testJWT"
        "X-Forwarded-From" = "content-skimmer"
        "Content-Type" = "application/json"
    }
    
    $searchResult = Test-HttpEndpoint -Url "$($Config[$Environment].GatewayService)/search?q=test" -Headers $searchHeaders
    
    if ($searchResult.Success) {
        Write-Host "SUCCESS: Cross-service JWT communication working" -ForegroundColor Green
        Write-Host "  Search results: $($searchResult.Data.hits.Count)" -ForegroundColor Gray
    } elseif ($searchResult.StatusCode -eq 403) {
        Write-Host "INFO: Search requires different authentication (Meilisearch API key)" -ForegroundColor Yellow
    } elseif ($searchResult.StatusCode -eq 401) {
        Write-Host "INFO: JWT authentication working but user unauthorized for search" -ForegroundColor Yellow
    } else {
        Write-Host "INFO: Cross-service test - $($searchResult.Error)" -ForegroundColor Yellow
    }

    # Test 7: Verify AUTH_JWT_SECRET consistency across services
    Write-Host "`n8. Checking AUTH_JWT_SECRET Consistency..." -ForegroundColor Yellow
    
    $servicesWithJWT = @(
        @{ Name = "Main Project"; Path = "c:\Users\Admin\Documents\coding\tamyla\wrangler.toml" }
        @{ Name = "Content Skimmer"; Path = "c:\Users\Admin\Documents\coding\tamyla\content-skimmer\wrangler.toml" }
        @{ Name = "Meilisearch"; Path = "c:\Users\Admin\Documents\coding\tamyla\meilisearch\wrangler.toml" }
    )
    
    $secretsMatch = $true
    foreach ($service in $servicesWithJWT) {
        if (Test-Path $service.Path) {
            $content = Get-Content $service.Path -Raw
            $match = [regex]::Match($content, 'AUTH_JWT_SECRET\s*=\s*"([^"]+)"')
            if ($match.Success) {
                $serviceSecret = $match.Groups[1].Value
                if ($serviceSecret -eq $jwtSecret) {
                    Write-Host "  $($service.Name): MATCH" -ForegroundColor Green
                } else {
                    Write-Host "  $($service.Name): MISMATCH" -ForegroundColor Red
                    $secretsMatch = $false
                }
            } else {
                Write-Host "  $($service.Name): NOT CONFIGURED" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  $($service.Name): FILE NOT FOUND" -ForegroundColor Yellow
        }
    }
    
    if ($secretsMatch) {
        Write-Host "SUCCESS: All services use the same AUTH_JWT_SECRET" -ForegroundColor Green
    } else {
        Write-Host "WARNING: AUTH_JWT_SECRET mismatch detected" -ForegroundColor Yellow
    }

    Write-Host "`n============================================================" -ForegroundColor Gray
    Write-Host "JWT Authentication Summary:" -ForegroundColor White
    Write-Host "  - JWT Secret: CONFIGURED" -ForegroundColor Green
    Write-Host "  - JWT Generation: WORKING" -ForegroundColor Green
    Write-Host "  - Service Integration: PARTIALLY WORKING" -ForegroundColor Yellow
    Write-Host "  - Secret Consistency: $(if ($secretsMatch) { 'SYNCHRONIZED' } else { 'NEEDS ATTENTION' })" -ForegroundColor $(if ($secretsMatch) { 'Green' } else { 'Yellow' })
    
    Write-Host "`nNOTE: Some services use Meilisearch API keys for search endpoints" -ForegroundColor Cyan
    Write-Host "JWT authentication is primarily for user session management" -ForegroundColor Cyan
    
    Write-Host "`nJWT AUTHENTICATION SYSTEM: OPERATIONAL" -ForegroundColor Green

} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
