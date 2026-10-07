param([string]$OutputDirectory = 'assets/alien/audio', [string[]]$Only = @(), [switch]$Force)
$ErrorActionPreference = 'Stop'
if (-not $env:ELEVENLABS_API_KEY) { throw 'Configure ELEVENLABS_API_KEY in the environment.' }
$taskOutput = Join-Path (Get-Location) $OutputDirectory
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskHeaders = @{ 'xi-api-key' = $env:ELEVENLABS_API_KEY }
$taskSubscription = Invoke-RestMethod -Uri 'https://api.elevenlabs.io/v1/user/subscription' -Headers $taskHeaders
$taskItems = @(
    @{id='prepare'; seconds=0.5; text='A tiny futuristic containment capacitor charging with a clean short rising electric chirp. Immediate onset, dry isolated sci-fi game effect, no speech, no music.'},
    @{id='fire'; seconds=0.5; text='A compact playful science fiction containment pulse, sharp electric zap and soft airy tail, immediate onset, isolated arcade laser effect, no gunshot, no speech, no music.'},
    @{id='hit'; seconds=0.7; text='An energy bubble snapping shut around a small alien, satisfying soft resonant pop and brief bright electronic sparkle, isolated game capture effect, no gore, no speech, no music.'},
    @{id='empty'; seconds=0.5; text='A clearly audible medium-volume robotic denial beep and sharp capacitor click, crisp low buzzing electronic rejection, immediate strong onset, dry isolated arcade interface effect, not quiet, no speech, no music.'},
    @{id='dash'; seconds=0.5; text='A small alien hover thruster giving one quick boost, airy accelerating puff with a compact electronic whirr, immediate onset, isolated game effect, no explosion, no speech, no music.'},
    @{id='ready'; seconds=0.5; text='A soft tiny rising electronic readiness chirp, two clean notes, isolated futuristic interface sound with immediate onset, no speech, no music.'},
    @{id='wave'; seconds=0.8; text='A concise original Earth defense dispatch notification, urgent but playful electronic alert with three short ascending tones, isolated arcade game sound, no real emergency siren, no speech.'},
    @{id='win'; seconds=1.2; text='A short original playful science fiction containment success stinger, warm mechanical click followed by bright electronic ascending arpeggio, celebratory concise game feedback, no speech, no recognizable existing melody.'},
    @{id='lose'; seconds=1.0; text='A short original awkward electronic descending stinger for aliens breaching the defense, restrained comedic disappointment, isolated science fiction game sound, no laughter, no speech, no existing melody.'},
    @{id='landing'; seconds=1.0; text='A compact alien landing corridor activating over an Earth rooftop, low energy swell and soft airy spatial shimmer, immediate onset, isolated science fiction game sound, no speech, no music.'},
    @{id='collect'; seconds=0.8; text='A gentle futuristic tractor beam collecting an energy bubble, short smooth descending electric sweep and tiny container latch click, isolated sci-fi game sound, no speech, no music.'},
    @{id='ui'; seconds=0.5; text='A clearly audible medium-volume futuristic button confirmation, one crisp electronic pluck and tactile click, rounded bright tone, immediate strong onset, dry isolated user interface effect, not whisper quiet, no speech, no music.'},
    @{id='ambience'; seconds=20.0; loop=$true; text='Seamless sustained nighttime Earth city rooftop ambience during an alien invasion. Clearly audible continuous ventilation and wind with a deep hovering mothership engine drone. Spacious balanced background bed at a steady moderate recording level. No foreground events, no sirens, no birds, no voices, no music, no sudden volume changes.'}
)
$taskManifestPath = Join-Path $taskOutput 'manifest.json'
$taskManifest = @{}
if (Test-Path -LiteralPath $taskManifestPath) {
    foreach ($taskPreviousEntry in (Get-Content -LiteralPath $taskManifestPath -Raw | ConvertFrom-Json -AsHashtable)) { $taskManifest[$taskPreviousEntry.path] = $taskPreviousEntry }
}
foreach ($taskItem in $taskItems) {
    if ($Only.Count -gt 0 -and $taskItem.id -notin $Only) { continue }
    $taskFile = Join-Path $taskOutput ($taskItem.id + '.mp3')
    $taskRelativePath = 'assets/alien/audio/' + $taskItem.id + '.mp3'
    if ($Force -or -not (Test-Path -LiteralPath $taskFile)) {
        $taskBody = @{text=$taskItem.text; duration_seconds=$taskItem.seconds; prompt_influence=0.5; model_id='eleven_text_to_sound_v2'; loop=($taskItem.loop -eq $true)} | ConvertTo-Json -Compress
        $taskResponse = Invoke-WebRequest -Uri 'https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128' -Headers $taskHeaders -Method Post -ContentType 'application/json' -Body $taskBody -OutFile ($taskFile + '.new') -PassThru
        Move-Item -LiteralPath ($taskFile + '.new') -Destination $taskFile -Force
        $taskCost = $taskResponse.Headers['character-cost']
        Write-Output ('Generated ' + $taskItem.id + ' (' + (Get-Item -LiteralPath $taskFile).Length + ' bytes), billed credits: ' + $taskCost)
        $taskFree = $taskSubscription.tier -eq 'free'
        $taskManifest[$taskRelativePath] = @{path=$taskRelativePath; provider='ElevenLabs'; model='eleven_text_to_sound_v2'; prompt=$taskItem.text; duration_seconds=$taskItem.seconds; loop=($taskItem.loop -eq $true); generated_date='2026-10-07'; account_tier=$taskSubscription.tier; license_status= $(if ($taskFree) {'development_only_noncommercial'} else {'commercial_subscription'}); attribution= $(if ($taskFree) {'elevenlabs.io'} else {''}); must_regenerate_for_commercial_release=$taskFree; billed_credits=$taskCost}
    }
    @($taskManifest.Values) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $taskManifestPath -Encoding utf8
}
$taskAfter = Invoke-RestMethod -Uri 'https://api.elevenlabs.io/v1/user/subscription' -Headers $taskHeaders
Write-Output ('Completed ' + $taskManifest.Count + ' assets. Credits used now: ' + $taskAfter.character_count + ' / ' + $taskAfter.character_limit)
