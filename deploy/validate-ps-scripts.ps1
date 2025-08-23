$files = @(
  "${PSScriptRoot}\railway-deploy.ps1",
  "${PSScriptRoot}\create-search-key.ps1"
)
$hasError = $false
foreach ($f in $files) {
  Write-Host "\nChecking: $f"
  [ref]$errors = $null
  [ref]$tokens = $null
  try {
    [System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$errors,[ref]$tokens) | Out-Null
    if ($errors -and $errors.Count -gt 0) {
      $hasError = $true
      foreach ($e in $errors) {
        Write-Host "ERROR: $($e.Message) at $($e.Extent.StartLineNumber):$($e.Extent.StartColumn)"
      }
    } else {
      Write-Host "OK: $f"
    }
  } catch {
    Write-Host "EXCEPTION parsing $f : $_"
    $hasError = $true
  }
}
if ($hasError) { exit 1 } else { exit 0 }
