# List Meilisearch keys using MEILI_MASTER_KEY fetched from Railway
try {
    $varsJson = npx railway variables -s meilisearch-service --json 2>$null
} catch {
    Write-Error "Failed to run 'npx railway variables' - ensure Railway CLI is available"
    exit 2
}
if (-not $varsJson) { Write-Error "Failed to fetch Railway variables"; exit 2 }
$vars = $varsJson | ConvertFrom-Json
$master = $null
if ($vars -is [System.Collections.IDictionary]) { if ($vars.ContainsKey('MEILI_MASTER_KEY')) { $master = $vars['MEILI_MASTER_KEY'] } }
else { if ($vars.PSObject.Properties.Name -contains 'MEILI_MASTER_KEY') { $master = $vars.MEILI_MASTER_KEY } }
if (-not $master) { Write-Error "MEILI_MASTER_KEY not found"; exit 2 }
Write-Host "Using MEILI_MASTER_KEY (length: $($master.Length))"
try {
    $keys = Invoke-RestMethod -Uri 'https://meilisearch-service-production-01e0.up.railway.app/keys' -Headers @{ 'X-Meili-API-Key' = $master } -Method Get -ErrorAction Stop
    Write-Host "Keys:`n"; $keys | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Failed to list keys: $($_.Exception.Message)"
    if ($_.Exception.Response) { Write-Host "Status code: $($_.Exception.Response.StatusCode.Value__)" }
}
