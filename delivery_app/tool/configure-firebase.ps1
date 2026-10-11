param(
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$gradleFile = Join-Path $projectRoot 'android\app\build.gradle.kts'
$gradleText = Get-Content -LiteralPath $gradleFile -Raw -Encoding UTF8
$packageMatch = [regex]::Match($gradleText, 'applicationId\s*=\s*"([^"]+)"')
if (-not $packageMatch.Success) { throw 'Cannot determine applicationId from the app Gradle file.' }
$expectedPackage = $packageMatch.Groups[1].Value
$expectedProject = 'arjunlayover'
$sourcePath = (Resolve-Path -LiteralPath $ConfigPath).Path
$firebaseConfig = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($firebaseConfig.project_info.project_id -ne $expectedProject) {
    throw "Expected Firebase project '$expectedProject'. No configuration was copied."
}
$matchingClients = @($firebaseConfig.client | Where-Object {
    $_.client_info.android_client_info.package_name -eq $expectedPackage
})
if ($matchingClients.Count -ne 1) {
    throw "Register an Android app with package '$expectedPackage' in Firebase project '$expectedProject', then download its google-services.json. This file has no unique matching client. No configuration was copied."
}
$keys = @($matchingClients[0].api_key | Where-Object { $_.current_key })
if (-not $matchingClients[0].client_info.mobilesdk_app_id -or $keys.Count -eq 0) {
    throw 'The Firebase Android registration is incomplete. No configuration was copied.'
}
if ($ValidateOnly) {
    Write-Output "Valid Firebase registration for $expectedPackage in $expectedProject."
    exit 0
}
$targetPath = Join-Path $projectRoot 'android\app\google-services.json'
if ($sourcePath -ne $targetPath) {
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
}
Write-Output 'Installed android/app/google-services.json. Rebuild the Flutter app to enable Firebase.'
