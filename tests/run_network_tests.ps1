param([ValidateSet('lan','online')][string]$Transport = 'lan', [ValidateSet(3,4)][int]$Players = 3)
$ErrorActionPreference = 'Stop'
$taskEngine = 'E:\Godot\Godot_v4.7.2-stable_win64_console.exe'
$taskWorkspace = (Get-Location).Path
$taskLogs = Join-Path $taskWorkspace 'tests/evidence'
New-Item -ItemType Directory -Path $taskLogs -Force | Out-Null
$taskPeers = @()
$taskRoles = @('host','et','agent')
if ($Players -eq 4) { $taskRoles = @('host','et','et2','agent') }
try {
    foreach ($taskRole in $taskRoles) {
        $taskArguments = @('--headless','--path',('"' + $taskWorkspace + '"'),'res://tests/network_peer.tscn','--log-file',('"' + (Join-Path $taskLogs ($Transport + '-' + $taskRole + '.log')) + '"'),'--',$taskRole,$Transport,$Players)
        $taskPeers += Start-Process -FilePath $taskEngine -ArgumentList $taskArguments -PassThru -WindowStyle Hidden
        Start-Sleep -Milliseconds 450
    }
    $taskDeadline = [DateTime]::UtcNow.AddSeconds($(if ($Transport -eq 'online') {105} else {55}))
    while (@($taskPeers | Where-Object { -not $_.HasExited }).Count -gt 0 -and [DateTime]::UtcNow -lt $taskDeadline) {
        Start-Sleep -Milliseconds 300
    }
    foreach ($taskPeer in $taskPeers) {
        if (-not $taskPeer.HasExited) { throw 'A validation peer timed out.' }
        if ($taskPeer.ExitCode -ne 0) { throw ('Validation peer failed with exit code ' + $taskPeer.ExitCode) }
    }
    foreach ($taskRole in $taskRoles) {
        $taskText = Get-Content -LiteralPath (Join-Path $taskLogs ($Transport + '-' + $taskRole + '.log')) -Raw
        if (-not $taskText.Contains('PASS:')) { throw ('Missing success evidence for ' + $taskRole) }
        Write-Output ($taskText -split "`n" | Where-Object { $_ -match 'PASS:|SCRIPT ERROR:|ERROR:' })
    }
} finally {
    foreach ($taskPeer in $taskPeers) { if (-not $taskPeer.HasExited) { Stop-Process -Id $taskPeer.Id -Force } }
}
