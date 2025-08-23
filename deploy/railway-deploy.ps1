<#
PowerShell orchestration script to deploy Meilisearch to Railway and wire GitHub Secrets.
Prerequisites:
- Install Railway CLI: https://docs.railway.app/develop/cli
- Install GitHub CLI (`gh`) and authenticate: https://cli.github.com/
- Ensure Docker is installed and running locally (for building image if needed)
- Run this script from the repo root or from the `deploy` folder

This script automates as much as possible, but Railway volume creation and retrieving the public host URL may require a quick manual step in the Railway dashboard.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Check-CommandPresent($cmd, $name) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$name is not installed or not in PATH. Please install and login before running this script."
        exit 2
    }
}

Check-CommandPresent -cmd 'railway' -name 'Railway CLI (railway)'
Check-CommandPresent -cmd 'gh' -name 'GitHub CLI (gh)'
Check-CommandPresent -cmd 'docker' -name 'Docker'

Write-Host "Generating strong secrets..."
# 32 bytes base64 for master key and JWT secret
$masterKey = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 }))
$jwtSecret = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 }))

Write-Host "Master key (first 8 chars): $($masterKey.Substring(0,8))"
Write-Host "JWT secret (first 8 chars): $($jwtSecret.Substring(0,8))"

Write-Host "
Step 1: Login to Railway (if not already)."
Write-Host "If you are not logged in, the Railway CLI will open a browser."
railway login

Write-Host "
Step 2: Initialize / deploy the service."
# Resolve script directory robustly for different invocation contexts
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Split-Path -Parent $scriptDir
$deployDir = Join-Path $repoRoot 'deploy'
Push-Location -Path $repoRoot
Set-Location -Path $deployDir

Write-Host "Running: railway init (interactive)"
# railway init will ask for a project name; if project exists, link instead
railway init

Write-Host "Deploying to Railway (this will build using the Dockerfile in deploy/)"
railway up

Write-Host "
NOTE: If Railway did not automatically create a persistent volume, please open the Railway dashboard, create a volume, and attach it to the service mapped to /data."

Write-Host "
Step 3: Get the public host URL from Railway and enter it now." 
$meiliHost = Read-Host "Enter the Meilisearch public host (e.g. https://meili-123.up.railway.app)"
if ([string]::IsNullOrWhiteSpace($meiliHost)) { Write-Error "Host is required"; exit 3 }

Write-Host "Creating a search-only key using the PowerShell helper."
# call the helper script that posts to /keys
$helper = Join-Path (Get-Location) 'create-search-key.ps1'
if (-not (Test-Path $helper)) { Write-Error "Helper create-search-key.ps1 not found in deploy folder"; exit 4 }

Write-Host "Calling create-search-key.ps1 against $meiliHost"
$createKeyResult = & $helper -MeiliHost $meiliHost -MasterKey $masterKey 2>&1
Write-Host $createKeyResult

# Attempt to parse key from JSON output
try {
    $json = $createKeyResult | Out-String | ConvertFrom-Json
    $searchKey = $json.key
} catch {
    Write-Warning "Could not parse search key from helper output, please run the helper manually and copy the key."
    $searchKey = Read-Host "Enter Search Key manually"
}

Write-Host "
Step 4: Add GitHub Secrets to the repository using gh CLI."
try {
    $repo = gh repo view --json nameWithOwner --jq .nameWithOwner 2>$null
} catch {
    $repo = $null
}
if (-not $repo) {
    Write-Warning "Could not detect repo via gh; please ensure gh is authenticated or set the repo manually."
} else {
    Write-Host "Detected repo: $repo"
}

# Confirm before setting secrets
$confirm = Read-Host "Proceed to set GitHub Actions secrets MEILISEARCH_HOST, MEILISEARCH_API_KEY, MEILISEARCH_SEARCH_KEY, AUTH_JWT_SECRET for $repo? (y/n)"
if ($confirm -ne 'y') { Write-Host "Skipping secrets setup"; exit 0 }

gh secret set MEILISEARCH_HOST --body $meiliHost
gh secret set MEILISEARCH_API_KEY --body $masterKey
gh secret set MEILISEARCH_SEARCH_KEY --body $searchKey
gh secret set AUTH_JWT_SECRET --body $jwtSecret

Write-Host "All done. Verify secrets in GitHub repo settings and open the Railway service to confirm health."

Pop-Location
