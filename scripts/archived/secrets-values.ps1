Write-Host "GITHUB SECRETS SETUP - TEMPLATE (no plaintext values)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This file previously contained plaintext secrets. For security, values were removed." -ForegroundColor Yellow
Write-Host "Please set the following repository secrets manually via GitHub UI or gh CLI:" -ForegroundColor White
Write-Host "  - MEILI_MASTER_KEY: <paste master key from Railway or generate new>" -ForegroundColor Gray
Write-Host "  - MEILI_SEARCH_KEY: <search-only key>" -ForegroundColor Gray
Write-Host "  - CLOUDFLARE_ACCOUNT_ID: <cloudflare account id>" -ForegroundColor Gray
Write-Host "  - CLOUDFLARE_API_TOKEN: <cloudflare api token with Workers:Edit>" -ForegroundColor Gray
Write-Host ""
Write-Host "IMPORTANT: Rotate any secret that was previously committed in plaintext." -ForegroundColor Red
