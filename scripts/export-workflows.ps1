# Exports the project's workflows from the running n8n into ./workflows as readable JSON.
# n8n export:workflow never includes credential secrets (only credential names and ids).
# Usage (from the repo root):  powershell -ExecutionPolicy Bypass -File .\scripts\export-workflows.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

# n8n workflow id -> file name in the repo
$project = [ordered]@{
  'UFHi9gGay7YM3vUj' = '01-synthetic-catalogue-api.json'
  'IYDMLvnLsL4mTuSf' = '02-candidate-to-jobs-matching-engine.json'
  '8y9qe5N7C2bieCGO' = '05-error-capture-and-alert.json'
  'BFQ6Mp6WXagUlQo6' = '06-ai-explanation.json'
  'hqmkMSIzximxZYL5' = '07-persist-recommendations-postgres.json'
  'qhsXJbitOHxFF0Dn' = '09-live-public-internship-feed.json'
  'XHNepdnitiMYhMnh' = '10-recruiter-ranking-engine.json'
  'rX372U9q6KEycZYn' = '11-recruiter-ranking-manual-test.json'
  'SMcDlgwWxfg1f6f4' = '12-telegram-controller.json'
  'c9TQ0w5cfqY11MI3' = '12-test-controller-no-telegram-sends.json'
}

docker compose exec -T n8n sh -c "rm -rf /tmp/repo-export && mkdir -p /tmp/repo-export && n8n export:workflow --all --separate --pretty --output=/tmp/repo-export"
if ($LASTEXITCODE -ne 0) { throw 'n8n export failed' }
$raw = Join-Path $root 'export-raw'
Remove-Item $raw -Recurse -Force -ErrorAction SilentlyContinue
docker compose cp n8n:/tmp/repo-export/. $raw | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'copy from container failed' }

Remove-Item (Join-Path $root 'workflows\*.json') -ErrorAction SilentlyContinue
foreach ($id in $project.Keys) {
  $src = Join-Path $raw "$id.json"
  if (-not (Test-Path $src)) { throw "Workflow $id not found in n8n" }
  Copy-Item $src (Join-Path $root "workflows\$($project[$id])")
}
Remove-Item $raw -Recurse -Force

# Safety net: refuse to leave anything that looks like a secret in the export
$hits = Select-String -Path (Join-Path $root 'workflows\*.json') -Pattern 'sk-or-v1-|bot[0-9]{8,}:|"password"\s*:\s*"[^"]' -List
if ($hits) { $hits | ForEach-Object { Write-Host "Possible secret in $($_.Filename)" -ForegroundColor Red }; throw 'Secret check failed' }

Get-ChildItem (Join-Path $root 'workflows') | Select-Object Name, Length
Write-Host 'Exported. Review with: git diff --stat' -ForegroundColor Green
