# Hisaab Book release helper.
#
# Usage (from the project root):
#   .\scripts\release.ps1
#   .\scripts\release.ps1 -Version 1.2.0 -Notes "Naya feature"
#
# Default behaviour: patch version bump + next build number, tests, release
# APK build, git tag push, and a public GitHub release with APK + SHA-256.

[CmdletBinding()]
param(
    [string]$Version = "",
    [int]$Build = 0,
    [string]$Notes = "",
    [switch]$SkipTests,
    [switch]$SkipPush,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Run([string]$Command) {
    Write-Host "> $Command" -ForegroundColor Cyan
    # Native tools (Flutter/Gradle) stderr par warning likhte hain. Warning ko
    # terminating error banne se rokna zaroori hai, warna script build ke baad
    # ruk jata hai. Asli failure $LASTEXITCODE se check hoti hai.
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        Invoke-Expression $Command
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($exitCode -ne 0) {
        Fail "Command fail hua: $Command"
    }
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path (Join-Path $root ".git"))) {
    Fail "Ye folder git repo nahi hai. Pehle git init aur GitHub remote setup karo."
}

$dirty = git status --porcelain
if ($dirty -and -not $DryRun) {
    Write-Host "Working tree me changes hain:" -ForegroundColor Yellow
    $dirty | ForEach-Object { Write-Host "  $_" }
    Fail "Release se pehle working tree clean rakho."
}

if (-not $DryRun) {
    $remote = git remote get-url origin 2>$null
    if (-not $remote) {
        Fail "Git remote 'origin' set nahi hai."
    }

    $ghAuth = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Fail "GitHub CLI login nahi hai. 'gh auth login' chalao."
    }
}

$pubspecPath = Join-Path $root "pubspec.yaml"
$pubspec = Get-Content $pubspecPath -Raw
$versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$')
if (-not $versionMatch.Success) {
    Fail "pubspec.yaml me 'version: x.y.z+build' format nahi mila."
}

$oldMajor = [int]$versionMatch.Groups[1].Value
$oldMinor = [int]$versionMatch.Groups[2].Value
$oldPatch = [int]$versionMatch.Groups[3].Value
$oldBuild = [int]$versionMatch.Groups[4].Value

$newVersion = ""
$newBuild = 0

if ($Version -match '^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$') {
    $newVersion = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
    if ($Matches[4]) {
        $newBuild = [int]$Matches[4]
    }
    elseif ($Build -gt 0) {
        $newBuild = $Build
    }
    else {
        $newBuild = $oldBuild + 1
    }
}
elseif ([string]::IsNullOrWhiteSpace($Version)) {
    $newVersion = "$oldMajor.$oldMinor.$($oldPatch + 1)"
    $newBuild = if ($Build -gt 0) { $Build } else { $oldBuild + 1 }
}
else {
    Fail "Version format galat hai. Example: -Version 1.2.0 -Build 5"
}

if ($newBuild -le $oldBuild) {
    Fail "Naya build number ($newBuild) purane ($oldBuild) se bada hona chahiye."
}

$tag = "v$newVersion+$newBuild"
$existingTag = git tag --list $tag
if ($existingTag) {
    Fail "Tag '$tag' pehle se exists karta hai."
}

if ([string]::IsNullOrWhiteSpace($Notes)) {
    $Notes = "Hisaab Book $newVersion update.`n`n- Bug fixes aur improvements."
}

Write-Host "Release: $newVersion+$newBuild ($tag)" -ForegroundColor Green
Write-Host "Purana version: $oldMajor.$oldMinor.$oldPatch+$oldBuild"

if ($DryRun) {
    Write-Host "Dry run: kuch bhi modify/build/push nahi hua." -ForegroundColor Yellow
    exit 0
}

$updatedPubspec = [regex]::Replace(
    $pubspec,
    '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$',
    "version: $newVersion+$newBuild"
)
Set-Content -Path $pubspecPath -Value $updatedPubspec -NoNewline

Run "C:\flutter\bin\flutter.bat pub get"
Run "C:\flutter\bin\flutter.bat analyze"
if (-not $SkipTests) {
    Run "C:\flutter\bin\flutter.bat test"
}
Run "C:\flutter\bin\flutter.bat build apk --release"

$sourceApk = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $sourceApk)) {
    Fail "Release APK nahi mili: $sourceApk"
}

$assetDir = Join-Path $root "build\release-assets"
New-Item -ItemType Directory -Path $assetDir -Force | Out-Null
$assetName = "hisaab-book-$newVersion+$newBuild.apk"
$assetApk = Join-Path $assetDir $assetName
Copy-Item -Path $sourceApk -Destination $assetApk -Force

$hash = (Get-FileHash -Algorithm SHA256 -Path $assetApk).Hash.ToLowerInvariant()
$checksumPath = "$assetApk.sha256"
Set-Content -Path $checksumPath -Value "$hash  $assetName" -NoNewline -Encoding ascii

$notesPath = Join-Path $assetDir "release-notes.txt"
Set-Content -Path $notesPath -Value $Notes -Encoding utf8

Run "git add pubspec.yaml"
Run "git commit -m `"Release $tag`""
Run "git tag $tag"

if (-not $SkipPush) {
    Run "git push origin HEAD"
    Run "git push origin $tag"

    Run "gh release create $tag `"$assetApk`" `"$checksumPath`" --title `"Hisaab Book $newVersion`" --notes-file `"$notesPath`""
    $releaseUrl = gh release view $tag --json url --jq .url
    Write-Host ""
    Write-Host "Release ready: $releaseUrl" -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Push skipped. APK yahan hai: $assetApk" -ForegroundColor Yellow
}
