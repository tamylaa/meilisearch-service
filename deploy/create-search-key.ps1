param(
  [string]$MeiliHost = 'http://localhost:7700',
  [string]$MasterKey = 'masterKey'
)

$body = '{ "description":"search-key","actions":["search"],"indexes":["*"] }'

$headers = @{
  Authorization = "Bearer $MasterKey"
  'Content-Type' = 'application/json'
}

try {
  $response = Invoke-RestMethod -Method Post -Uri "$MeiliHost/keys" -Body $body -Headers $headers
  $response | ConvertTo-Json -Depth 5
} catch {
  Write-Error "Failed to create search key: $_"
  exit 1
}
