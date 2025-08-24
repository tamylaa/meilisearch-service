# Diagnostic script: fetch MEILI_SEARCH_KEY from Railway and compare direct Meilisearch vs Gateway search
try {
    $varsJson = npx railway variables -s meilisearch-service --json 2>$null
} catch {
    Write-Error "Failed to run 'npx railway variables' - ensure Railway CLI is available"
    exit 2
}
if (-not $varsJson) {
    Write-Error "Failed to fetch Railway variables or no output returned"
    exit 2
}
$vars = $varsJson | ConvertFrom-Json
# Railway CLI returns a JSON object with keys as properties. Access MEILI_SEARCH_KEY directly.
$key = $null
if ($vars -is [System.Collections.IDictionary]) {
    # When parsed as dictionary-like object
    if ($vars.ContainsKey('MEILI_SEARCH_KEY')) { $key = $vars['MEILI_SEARCH_KEY'] }
} else {
    # When parsed as PSCustomObject with properties
    if ($vars.PSObject.Properties.Name -contains 'MEILI_SEARCH_KEY') { $key = $vars.MEILI_SEARCH_KEY }
}
if (-not $key) {
    Write-Error "MEILI_SEARCH_KEY not found in Railway variables"
    exit 2
}
Write-Host "MEILI_SEARCH_KEY found (length: $($key.Length))"
$body = @{ q = 'setup'; limit = 1 } | ConvertTo-Json
Write-Host "--- Direct Meilisearch (Railway) search ---"
try {
    $direct = Invoke-RestMethod -Uri 'https://meilisearch-service-production-01e0.up.railway.app/indexes/setup-test-index/search' -Method Post -Headers @{ Authorization = "Bearer $key"; 'Content-Type' = 'application/json' } -Body $body -ErrorAction Stop
    Write-Host "Direct search response:`n"; $direct | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Direct search failed: $($_.Exception.Message)"
    if ($_.Exception.Response) { Write-Host "Status code: $($_.Exception.Response.StatusCode.Value__)" }
}
Write-Host "`n--- Direct Meilisearch with X-Meili-API-Key header ---"
try {
    $direct2 = Invoke-RestMethod -Uri 'https://meilisearch-service-production-01e0.up.railway.app/indexes/setup-test-index/search' -Method Post -Headers @{ 'X-Meili-API-Key' = $key; 'Content-Type' = 'application/json' } -Body $body -ErrorAction Stop
    Write-Host "Direct (X-Meili-API-Key) response:`n"; $direct2 | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Direct (X-Meili-API-Key) failed: $($_.Exception.Message)"
    if ($_.Exception.Response) { Write-Host "Status code: $($_.Exception.Response.StatusCode.Value__)" }
}

Write-Host "`n--- Direct index GET ---"
try {
    $idx = Invoke-RestMethod -Uri 'https://meilisearch-service-production-01e0.up.railway.app/indexes/setup-test-index' -Method Get -Headers @{ 'X-Meili-API-Key' = $key } -ErrorAction Stop
    Write-Host "Index GET response:`n"; $idx | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Index GET failed: $($_.Exception.Message)"
    if ($_.Exception.Response) { Write-Host "Status code: $($_.Exception.Response.StatusCode.Value__)" }
}
Write-Host "`n--- Gateway search ---"
try {
    $gateway = Invoke-RestMethod -Uri 'https://search.tamyla.com/search?q=setup&limit=1' -Method Get -Headers @{ Authorization = "Bearer $key" } -ErrorAction Stop
    Write-Host "Gateway response:`n"; $gateway | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Gateway search failed: $($_.Exception.Message)"
    if ($_.Exception.Response) { Write-Host "Status code: $($_.Exception.Response.StatusCode.Value__)" }
}
