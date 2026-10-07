param([switch]$Commercial, [string]$Godot = 'E:\Godot\Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$taskAudioManifest = Get-Content -LiteralPath 'assets/alien/audio/manifest.json' -Raw | ConvertFrom-Json
if ($Commercial -and @($taskAudioManifest | Where-Object { $_.must_regenerate_for_commercial_release }).Count -gt 0) {
    throw 'Commercial export blocked: the ElevenLabs audio was generated on a free plan. Regenerate every audio asset during a commercially licensed subscription before publishing.'
}
$taskBuildFolder = if ($Commercial) { 'build/release' } else { 'build/testes' }
New-Item -ItemType Directory -Path $taskBuildFolder -Force | Out-Null
Set-Content -LiteralPath 'build/.gdignore' -Value ''
$taskMode = if ($Commercial) { '--export-release' } else { '--export-debug' }
$taskOutput = Join-Path $taskBuildFolder 'AlertaTerra.exe'
& $Godot --headless --path . $taskMode 'Windows Desktop' $taskOutput --log-file (Join-Path $taskBuildFolder 'export.log')
if ($LASTEXITCODE -ne 0) { throw ('Godot export failed with exit code ' + $LASTEXITCODE) }
@'
ALERTA: TERRA - TEST BUILD
Audio generated with ElevenLabs (elevenlabs.io) on a free plan: noncommercial development use only.
Regenerate the audio under a commercially licensed subscription before publication.
Pixel art created with PixelLab. Original source prompts and asset IDs are in assets/alien/art/manifest.json.
'@ | Set-Content -LiteralPath (Join-Path $taskBuildFolder 'LEIA-ANTES-DE-PUBLICAR.txt') -Encoding utf8
Write-Output ('Build saved to ' + $taskOutput)
