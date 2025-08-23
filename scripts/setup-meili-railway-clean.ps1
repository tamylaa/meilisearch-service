# setup-meili-railway.ps1
# Meilisearch Railway setup script - Windows PowerShell v5.1 compatible

param(
    [string]$PublicHost = 'https://meilisearch-service-production-01e0.up.railway.app',
    [string]$MasterKey,
    [switch]$AutoRedeploy = $false,
    [int]$PollIntervalSeconds = 2,
    [int]$MaxPollAttempts = 30
)

Set-StrictMode -Version Latest

function New-MasterKey {
    $bytes = New-Object Byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $b64 = [Convert]::ToBase64String($bytes)
    $urlsafe = $b64 -replace '\+', '-' -replace '/', '_' -replace '=', ''
    return $urlsafe
}

function Get-RailwayVarsJson {
    try {
        $out = & npx railway variables -s meilisearch-service -- --json 2>$null
        if (-not $out) { return $null }
        $raw = $out -join "`n"
        return $raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

try {
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        Write-Host 'npx (Railway CLI) not found in PATH. Install Node.js/npm or run from environment with npx.' -ForegroundColor Red
        exit 2
    }

    if ($PublicHost.EndsWith('/')) { 
        $PublicHost = $PublicHost.Substring(0, $PublicHost.Length - 1) 
    }

    if (-not $MasterKey) {
        $vars = Get-RailwayVarsJson
        if ($vars -and $vars.MEILI_MASTER_KEY) {
            $MasterKey = $vars.MEILI_MASTER_KEY
            Write-Host 'Using existing MEILI_MASTER_KEY from Railway'
        }
    }

    $didSetMasterKey = $false
    if (-not $MasterKey) {
        $MasterKey = New-MasterKey
        Write-Host "Generated MEILI_MASTER_KEY: $MasterKey"
        & npx railway variables --set "MEILI_MASTER_KEY=$MasterKey" -s meilisearch-service
        & npx railway variables --set ".EILI_MASTER_KEY=" -s meilisearch-service
        $didSetMasterKey = $true
    }

    if ($didSetMasterKey -and $AutoRedeploy) {
        Write-Host "AutoRedeploy: running 'npx railway up' to apply new vars"
        & npx railway up
    }

    if ($didSetMasterKey) {
        Write-Host "Waiting for Meilisearch to accept the master key (up to $MaxPollAttempts attempts)..."
        $i = 0
        $accepted = $false
        while ($i -lt $MaxPollAttempts -and -not $accepted) {
            Start-Sleep -Seconds $PollIntervalSeconds
            $i = $i + 1
            try {
                $hdr = @{ Authorization = "Bearer $MasterKey" }
                $ver = Invoke-RestMethod -Method Get -Uri "$PublicHost/version" -Headers $hdr -ErrorAction Stop
                if ($ver) { 
                    $accepted = $true
                    break 
                }
            } catch {
                Write-Host "Master key not active yet (attempt $i/$MaxPollAttempts)"
            }
        }
        if (-not $accepted) { 
            Write-Host 'Master key did not become active in time. Redeploy and retry.'
            exit 3 
        }
    }

    try {
        $health = Invoke-RestMethod -Method Get -Uri "$PublicHost/health" -ErrorAction Stop
        Write-Host "Health: $($health | ConvertTo-Json -Depth 2)"
    } catch {
        Write-Host "Unable to reach $PublicHost/health : $($_.Exception.Message)"
        exit 4
    }

    $testIndex = 'setup-test-index'
    try {
        Invoke-RestMethod -Method Get -Uri "$PublicHost/indexes/$testIndex" -Headers @{ Authorization = "Bearer $MasterKey" } -ErrorAction Stop
        Write-Host 'Index exists'
    } catch {
        $body = @{ uid = $testIndex } | ConvertTo-Json
        Invoke-RestMethod -Method Post -Uri "$PublicHost/indexes" -Headers @{ Authorization = "Bearer $MasterKey"; 'Content-Type' = 'application/json' } -Body $body -ErrorAction Stop
        Write-Host 'Index created'
    }

    $docs = @(@{ id = 1; title = 'setup check' }) | ConvertTo-Json
    $addResp = Invoke-RestMethod -Method Post -Uri "$PublicHost/indexes/$testIndex/documents" -Headers @{ Authorization = "Bearer $MasterKey"; 'Content-Type' = 'application/json' } -Body $docs -ErrorAction Stop

    $updateId = $null
    if ($addResp -and $addResp.PSObject.Properties['updateId']) { 
        $updateId = $addResp.updateId 
    } elseif ($addResp -and $addResp.PSObject.Properties['update_id']) { 
        $updateId = $addResp.update_id 
    } elseif ($addResp -and $addResp.PSObject.Properties['taskUid']) { 
        $updateId = $addResp.taskUid 
    } elseif ($addResp -is [string]) { 
        $updateId = $addResp 
    }

    if ($updateId) {
        $i = 0
        $processed = $false
        while ($i -lt $MaxPollAttempts -and -not $processed) {
            Start-Sleep -Seconds $PollIntervalSeconds
            $i = $i + 1
            try {
                $status = Invoke-RestMethod -Method Get -Uri "$PublicHost/tasks/$updateId" -Headers @{ Authorization = "Bearer $MasterKey" } -ErrorAction Stop
                Write-Host "Task status: $($status.status)"
                if ($status.status -eq 'succeeded') { 
                    $processed = $true
                    break 
                }
                if ($status.status -eq 'failed') { 
                    Write-Host "Index update failed"
                    exit 5 
                }
            } catch {
                Write-Host "Waiting for task... (attempt $i)"
            }
        }
        if (-not $processed) { 
            Write-Host 'Timed out waiting for indexing to complete'
            exit 6 
        }
    }

    $keyBody = @{ description = 'search-only-setup'; actions = @('search'); indexes = @($testIndex); expiresAt = $null } | ConvertTo-Json -Depth 4
    $keyResp = Invoke-RestMethod -Method Post -Uri "$PublicHost/keys" -Headers @{ Authorization = "Bearer $MasterKey"; 'Content-Type' = 'application/json' } -Body $keyBody -ErrorAction Stop
    if ($null -eq $keyResp.key) { 
        Write-Host 'Failed to create search key'
        exit 7 
    }
    $searchKey = $keyResp.key
    Write-Host "Created search key: $searchKey"

    & npx railway variables --set "MEILI_SEARCH_KEY=$searchKey" -s meilisearch-service

    $searchBody = @{ q = 'setup' } | ConvertTo-Json
    $searchResp = Invoke-RestMethod -Method Post -Uri "$PublicHost/indexes/$testIndex/search" -Headers @{ Authorization = "Bearer $searchKey"; 'Content-Type' = 'application/json' } -Body $searchBody -ErrorAction Stop
    Write-Host "Search sample: $($searchResp | ConvertTo-Json -Depth 3)"

    Write-Host 'Setup finished successfully.'

} catch {
    Write-Host "Error: $($_.Exception.Message)"
    exit 1
}
