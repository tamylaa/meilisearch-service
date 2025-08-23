# sync-credentials.ps1
# Synchronize Meilisearch credentials across Railway and Cloudflare Workers

param(
    [string]$SourceService = "meilisearch-service",
    [string]$Environment = "production",
    [switch]$DryRun = $false
)

Set-StrictMode -Version Latest

function Get-RailwayVariable {
    param([string]$VarName, [string]$ServiceName)
    
    try {
        $vars = & npx railway variables -s $ServiceName --json 2>$null | ConvertFrom-Json
        if ($vars.$VarName) {
            return $vars.$VarName
        }
        return $null
    } catch {
        Write-Host "Error getting Railway variable $VarName : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Set-CloudflareSecret {
    param([string]$SecretName, [string]$SecretValue, [string]$Environment)
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Would set Cloudflare secret: $SecretName (env: $Environment)" -ForegroundColor Yellow
        return $true
    }
    
    try {
        if ($Environment -eq "production") {
            $result = & npx wrangler secret put $SecretName --env production 2>&1
        } else {
            $result = & npx wrangler secret put $SecretName --env $Environment 2>&1
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully set Cloudflare secret: $SecretName" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Failed to set Cloudflare secret: $SecretName - $result" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Error setting Cloudflare secret $SecretName : $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Update-WranglerConfig {
    param([string]$MeilisearchUrl)
    
    $wranglerPath = "wrangler.toml"
    if (-not (Test-Path $wranglerPath)) {
        Write-Host "wrangler.toml not found in current directory" -ForegroundColor Red
        return $false
    }
    
    try {
        $content = Get-Content $wranglerPath -Raw
        
        # Update production environment
        if ($Environment -eq "production") {
            $content = $content -replace 'MEILISEARCH_URL = "https://search\.tamyla\.com"', "MEILISEARCH_URL = `"$MeilisearchUrl`""
        } elseif ($Environment -eq "staging") {
            $content = $content -replace 'MEILISEARCH_URL = "https://search-staging\.tamyla\.com"', "MEILISEARCH_URL = `"$MeilisearchUrl`""
        } else {
            $content = $content -replace 'MEILISEARCH_URL = "http://localhost:7700"', "MEILISEARCH_URL = `"$MeilisearchUrl`""
        }
        
        if ($DryRun) {
            Write-Host "[DRY RUN] Would update wrangler.toml with MEILISEARCH_URL: $MeilisearchUrl" -ForegroundColor Yellow
        } else {
            Set-Content $wranglerPath -Value $content
            Write-Host "Updated wrangler.toml with new MEILISEARCH_URL" -ForegroundColor Green
        }
        return $true
    } catch {
        Write-Host "Error updating wrangler.toml: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

try {
    Write-Host "=== Meilisearch Credential Sync ===" -ForegroundColor Cyan
    Write-Host "Environment: $Environment" -ForegroundColor White
    Write-Host "Source Service: $SourceService" -ForegroundColor White
    
    # Get credentials from Railway
    Write-Host "`nFetching credentials from Railway..." -ForegroundColor Yellow
    
    $masterKey = Get-RailwayVariable "MEILI_MASTER_KEY" $SourceService
    $searchKey = Get-RailwayVariable "MEILI_SEARCH_KEY" $SourceService
    $meilisearchUrl = Get-RailwayVariable "RAILWAY_STATIC_URL" $SourceService
    
    if (-not $masterKey) {
        Write-Host "MEILI_MASTER_KEY not found in Railway service $SourceService" -ForegroundColor Red
        exit 1
    }
    
    if (-not $searchKey) {
        Write-Host "MEILI_SEARCH_KEY not found in Railway service $SourceService" -ForegroundColor Red
        exit 1
    }
    
    if ($meilisearchUrl) {
        $meilisearchUrl = "https://$meilisearchUrl"
    } else {
        $meilisearchUrl = "https://meilisearch-service-production-01e0.up.railway.app"
    }
    
    Write-Host "✓ Master Key: ${masterKey.Substring(0,8)}..." -ForegroundColor Green
    Write-Host "✓ Search Key: ${searchKey.Substring(0,8)}..." -ForegroundColor Green
    Write-Host "✓ Meilisearch URL: $meilisearchUrl" -ForegroundColor Green
    
    # Navigate to content-skimmer directory
    $contentSkimmerPath = Join-Path (Get-Location).Path "..\content-skimmer"
    if (Test-Path $contentSkimmerPath) {
        Push-Location $contentSkimmerPath
        
        Write-Host "`nUpdating Cloudflare Worker secrets..." -ForegroundColor Yellow
        
        # Set secrets in Cloudflare Workers
        $success = $true
        
        # Use MEILISEARCH_API_KEY to match the existing content-skimmer interface
        if (-not (Set-CloudflareSecret "MEILISEARCH_API_KEY" $searchKey $Environment)) {
            $success = $false
        }
        
        # Master key for admin operations (if needed)
        if (-not (Set-CloudflareSecret "MEILI_MASTER_KEY" $masterKey $Environment)) {
            $success = $false
        }
        
        # Update wrangler.toml with the correct URL
        if (-not (Update-WranglerConfig $meilisearchUrl)) {
            $success = $false
        }
        
        Pop-Location
        
        if ($success) {
            Write-Host "`n✅ All credentials synchronized successfully!" -ForegroundColor Green
            Write-Host "`nNext steps:" -ForegroundColor Cyan
            Write-Host "1. Deploy content-skimmer: cd content-skimmer; npx wrangler deploy --env $Environment" -ForegroundColor White
            Write-Host "2. Test the integration between services" -ForegroundColor White
        } else {
            Write-Host "`n❌ Some operations failed. Check the output above." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Content-skimmer directory not found at $contentSkimmerPath" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
}
