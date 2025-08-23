param(
  [string]$MeiliHost = 'http://localhost:7700',
  [string]$MasterKey = 'masterKey'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Check-CommandPresent($cmd, $name) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$name is not available. Please ensure you are running this in PowerShell with network access."
        exit 2
    }
}

# Ensure we have an HTTP client available. Prefer Invoke-RestMethod, fall back to curl if necessary.
if (-not (Get-Command 'Invoke-RestMethod' -ErrorAction SilentlyContinue) -and -not (Get-Command 'curl' -ErrorAction SilentlyContinue)) {
  Write-Error "No HTTP client available. Install curl or run in PowerShell where Invoke-RestMethod is available."
  exit 2
}

$body = '{ "description":"search-key","actions":["search"],"indexes":["*"] }'

$headers = @{
  Authorization = "Bearer $MasterKey"
  'Content-Type' = 'application/json'
}

try {
  $response = Invoke-RestMethod -Method Post -Uri "$MeiliHost/keys" -Body $body -Headers $headers
  $response | ConvertTo-Json -Depth 5
} catch {
  Write-Error "Failed to create search key: $($_.Exception.Message)"
  exit 1
}
