param(
    [Parameter(Mandatory = $true)][string]$FontPath,
    [Parameter(Mandatory = $true)][string]$DistroName
)
$ErrorActionPreference = 'Stop'
$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
$destination = Join-Path $fontDir 'JetBrainsMonoNerdFontMono-Regular.ttf'
Copy-Item -LiteralPath $FontPath -Destination $destination -Force
New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' `
    -Name 'JetBrainsMono Nerd Font Mono (TrueType)' -Value $destination -PropertyType String -Force | Out-Null
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class DevOpsFont { [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceW(string name); }'
if ([DevOpsFont]::AddFontResourceW($destination) -eq 0) { throw 'Could not load the Nerd Font.' }

$paths = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
)
$updated = $false
foreach ($settings in $paths) {
    if (-not (Test-Path -LiteralPath $settings)) { continue }
    # Parse before writing: unsupported JSONC/custom settings remain untouched.
    try { $config = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json }
    catch { Write-Warning "Cannot parse $settings; select JetBrainsMono Nerd Font Mono manually. $_"; continue }
    $profiles = @($config.profiles.list | Where-Object { $_.name -eq $DistroName -and $_.source -eq 'Microsoft.WSL' })
    if ($profiles.Count -eq 0) { continue }
    $changed = $false
    foreach ($profile in $profiles) {
        if ($profile.font.face -eq 'JetBrainsMono Nerd Font Mono') { $updated = $true; continue }
        if (-not $profile.font) {
            $profile | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{}) -Force
        }
        $profile.font | Add-Member -NotePropertyName face -NotePropertyValue 'JetBrainsMono Nerd Font Mono' -Force
        $changed = $true
    }
    if ($changed) {
        $json = $config | ConvertTo-Json -Depth 100
        Copy-Item -LiteralPath $settings -Destination ($settings + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fffffff'))
        $temporary = $settings + '.devops-tmp'
        [System.IO.File]::WriteAllText($temporary, $json, (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $temporary -Destination $settings -Force
        $updated = $true
    }
}
if (-not $updated) { Write-Warning "No matching Windows Terminal profile for $DistroName was updated. Select JetBrainsMono Nerd Font Mono manually." }
Write-Output 'Nerd Font installed. Close and reopen Windows Terminal.'
