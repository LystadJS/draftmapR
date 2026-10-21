param([Parameter(Mandatory=$true)][string]$ExpectedHead)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$container = 'driftmapr-collection-20261021'
$ops = '/workspace/scratch/837e4400dd1d/study07-r1-operations'
$evidence = Join-Path $PSScriptRoot '2026-10-21/continuation'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
function Docker([string[]]$Arguments) {
    $result = & docker.exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Docker failed: $Arguments" }
    return $result
}
function Git([string[]]$Arguments) {
    $result = & git.exe -c "safe.directory=$($repo.Replace('\','/'))" -C $repo @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed: $Arguments" }
    return $result
}
function Save-Step([string]$Message) {
    if ((Git @('rev-parse','HEAD')) -ne $script:ExpectedHead) { throw 'Repository HEAD changed; preserve evidence for review' }
    if ((Git @('branch','--show-current')) -ne 'main') { throw 'Unexpected branch' }
    Git @('diff','--cached','--quiet') | Out-Null
    Git @('add','--','validation/2026-10-21/continuation') | Out-Host
    Git @('commit','-m',$Message) | Out-Host
    $script:ExpectedHead = Git @('rev-parse','HEAD')
    Git @('push','origin','main') | Out-Host
}
try {
    while ($true) {
        $state = (Docker @('exec',$container,'cat',"$ops/execution-process.json")) -join "`n" | ConvertFrom-Json
        if ($state.command[-1] -ne '/validation/validate-partial.R') { throw 'Unexpected validation process ownership' }
        if ($state.child_state -like 'paused_*') { throw "Validation paused: $($state.paused_reason)" }
        if ($state.child_state -eq 'exited') { break }
        Start-Sleep -Seconds 30
    }
    if ($state.status -ne 'exited_successfully') { throw "Validation failed: $($state.status), exit $($state.exit_code)" }
    $receipt = (Docker @('exec',$container,'cat',"$ops/partial-validation-20261021.json")) -join "`n" | ConvertFrom-Json
    if ($receipt.status -ne 'passed' -or $receipt.committed_panels -ne 3916) { throw 'Invalid partial validation receipt' }
    Docker @('cp',"${container}:$ops/partial-validation-20261021.json",(Join-Path $evidence 'partial-validation.json')) | Out-Host
    Docker @('cp',"${container}:$($state.log)",(Join-Path $evidence 'partial-validation.log')) | Out-Host
    $state | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $evidence 'partial-process.json')
    Save-Step 'Validate recovered partial panel 3916 against frozen serialization'
    Docker @('exec','-d',$container,'sh','-c','PYTHONDONTWRITEBYTECODE=1 python3 /validation/guard-continuation.py collect > /upper/collection-supervisor.log 2>&1') | Out-Host
    $oldToken = $state.supervisor_token
    $owned = $false
    for ($i=0; $i -lt 12; $i++) {
        Start-Sleep -Seconds 5
        $state = (Docker @('exec',$container,'cat',"$ops/execution-process.json")) -join "`n" | ConvertFrom-Json
        if ($state.supervisor_token -ne $oldToken) { $owned=$true; break }
    }
    if (!$owned -or $state.child_state -ne 'running' -or $state.command[1] -ne "$ops/resume-collection-prefix-006.R") { throw 'Collection launch did not establish a new running owned process' }
    $state | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $evidence 'collection-start.json')
    Save-Step 'Resume guarded deterministic collection after partial validation'
    Write-Output 'Guarded collection launched; scientific completion remains unverified.'
} catch {
    $_ | Out-String | Set-Content (Join-Path $evidence 'controller-error.txt')
    Write-Error $_
    exit 1
}
