param([string]$Environment = "production")

Write-Host "Running core meilisearch tests for environment: $Environment" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$testScripts = @('url-checker.ps1', 'test-actual-worker.ps1', 'integration-test.ps1')
$results = @()

foreach ($script in $testScripts) {
    $scriptPath = Join-Path $scriptDir $script
    
    if (Test-Path $scriptPath) {
        Write-Host "Running: $script" -ForegroundColor Yellow
        $proc = Start-Process -FilePath powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) -NoNewWindow -Wait -PassThru
        $exitCode = $proc.ExitCode
        
        if ($exitCode -eq 0) {
            Write-Host "PASS: $script" -ForegroundColor Green
            $results += @{Script = $script; Status = 'PASS'; ExitCode = $exitCode}
        } else {
            Write-Host "FAIL: $script (exit code: $exitCode)" -ForegroundColor Red
            $results += @{Script = $script; Status = 'FAIL'; ExitCode = $exitCode}
        }
    } else {
        Write-Host "SKIP: $script (not found)" -ForegroundColor Yellow
        $results += @{Script = $script; Status = 'SKIP'; ExitCode = -1}
    }
    Write-Host ""
}

$passed = ($results | Where-Object { $_.Status -eq 'PASS' }).Count
$total = $results.Count

Write-Host "Summary: $passed/$total tests passed" -ForegroundColor Cyan

if ($passed -eq $total) {
    exit 0
} else {
    exit 1
}