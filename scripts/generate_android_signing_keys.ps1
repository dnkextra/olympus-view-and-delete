param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function New-RandomSecret([int]$Bytes = 32) {
    $buffer = New-Object byte[] $Bytes
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($buffer)
    } finally {
        $rng.Dispose()
    }
    return [Convert]::ToBase64String($buffer).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-KeytoolPath {
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "$env:JAVA_HOME\bin\keytool.exe",
        "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
        "C:\flutter\bin\cache\artifacts\engine\android-arm\keytool.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }

    if ($candidates.Count -gt 0) { return $candidates[0] }
    throw 'keytool.exe was not found. Install/use the JDK bundled with Android Studio and run again.'
}

function Get-Sha256Fingerprint(
    [string]$Keytool,
    [string]$Keystore,
    [string]$StorePassword,
    [string]$Alias
) {
    $output = & $Keytool -list -v -keystore $Keystore -storepass $StorePassword -alias $Alias 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect $Keystore" }
    $line = $output | Select-String -Pattern 'SHA256:' | Select-Object -First 1
    if (-not $line) { throw "SHA-256 fingerprint was not found for $Alias" }
    return (($line.Line -replace '^.*SHA256:\s*', '') -replace ':', '').Trim().ToLowerInvariant()
}

$keytool = Get-KeytoolPath
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $env:USERPROFILE '.olympus-view\signing'
$appKeystore = Join-Path $outDir 'olympus-app-signing.jks'
$uploadKeystore = Join-Path $outDir 'olympus-play-upload.jks'
$appCert = Join-Path $outDir 'olympus-app-signing-cert.pem'
$uploadCert = Join-Path $outDir 'olympus-play-upload-cert.pem'
$secretsFile = Join-Path $outDir 'github-secrets.txt'
$keyProperties = Join-Path $root 'android\key.properties'

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

if (-not $Force) {
    foreach ($path in @($appKeystore, $uploadKeystore, $secretsFile)) {
        if (Test-Path $path) {
            throw "Signing material already exists at $path. Refusing to overwrite it. Use -Force only if you intentionally want brand-new keys."
        }
    }
}

$appStorePassword = New-RandomSecret
$appKeyPassword = New-RandomSecret
$uploadStorePassword = New-RandomSecret
$uploadKeyPassword = New-RandomSecret
$appAlias = 'olympus-app-signing'
$uploadAlias = 'olympus-play-upload'
$dname = 'CN=Olympus View, OU=Android, O=Olympus View'

Write-Host '[1/6] Generating long-lived production app-signing key...'
& $keytool -genkeypair -v `
    -keystore $appKeystore -storetype JKS `
    -storepass $appStorePassword -keypass $appKeyPassword `
    -alias $appAlias -keyalg RSA -keysize 4096 -sigalg SHA256withRSA `
    -validity 36500 -dname $dname -noprompt
if ($LASTEXITCODE -ne 0) { throw 'Failed to generate production app-signing key.' }

Write-Host '[2/6] Generating separate Google Play upload key...'
& $keytool -genkeypair -v `
    -keystore $uploadKeystore -storetype JKS `
    -storepass $uploadStorePassword -keypass $uploadKeyPassword `
    -alias $uploadAlias -keyalg RSA -keysize 4096 -sigalg SHA256withRSA `
    -validity 36500 -dname $dname -noprompt
if ($LASTEXITCODE -ne 0) { throw 'Failed to generate Google Play upload key.' }

Write-Host '[3/6] Exporting public certificates...'
& $keytool -exportcert -rfc -keystore $appKeystore -storepass $appStorePassword -alias $appAlias -file $appCert | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to export app-signing certificate.' }
& $keytool -exportcert -rfc -keystore $uploadKeystore -storepass $uploadStorePassword -alias $uploadAlias -file $uploadCert | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to export Play upload certificate.' }

Write-Host '[4/6] Reading certificate fingerprints...'
$appSha256 = Get-Sha256Fingerprint $keytool $appKeystore $appStorePassword $appAlias
$uploadSha256 = Get-Sha256Fingerprint $keytool $uploadKeystore $uploadStorePassword $uploadAlias
if ($appSha256 -eq $uploadSha256) { throw 'App-signing and Play upload certificates unexpectedly match.' }

Write-Host '[5/6] Creating local android/key.properties for GitHub/direct APK builds...'
$appPathForGradle = $appKeystore.Replace('\', '/')
@"
storeFile=$appPathForGradle
storePassword=$appStorePassword
keyAlias=$appAlias
keyPassword=$appKeyPassword
"@ | Set-Content -Encoding ASCII -Path $keyProperties

Write-Host '[6/6] Preparing GitHub Actions secret values...'
$appB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($appKeystore))
$uploadB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($uploadKeystore))
@"
# Olympus View Android signing secrets
# KEEP THIS FILE PRIVATE. Delete it after copying the values to GitHub Actions secrets.

ANDROID_KEYSTORE_BASE64=$appB64
ANDROID_KEYSTORE_PASSWORD=$appStorePassword
ANDROID_KEY_ALIAS=$appAlias
ANDROID_KEY_PASSWORD=$appKeyPassword
ANDROID_SIGNING_CERT_SHA256=$appSha256

PLAY_UPLOAD_KEYSTORE_BASE64=$uploadB64
PLAY_UPLOAD_KEYSTORE_PASSWORD=$uploadStorePassword
PLAY_UPLOAD_KEY_ALIAS=$uploadAlias
PLAY_UPLOAD_KEY_PASSWORD=$uploadKeyPassword
PLAY_UPLOAD_CERT_SHA256=$uploadSha256
"@ | Set-Content -Encoding ASCII -Path $secretsFile

Write-Host ''
Write-Host '========================================'
Write-Host ' Olympus View production signing ready'
Write-Host '========================================'
Write-Host "Production app-signing SHA-256: $appSha256"
Write-Host "Play upload SHA-256:            $uploadSha256"
Write-Host ''
Write-Host "Private keys:  $outDir"
Write-Host "Local signing: $keyProperties"
Write-Host "GitHub values: $secretsFile"
Write-Host ''
Write-Host 'IMPORTANT:'
Write-Host '1. Back up BOTH JKS files in at least two protected locations.'
Write-Host '2. Put the values from github-secrets.txt into Repository -> Settings -> Secrets and variables -> Actions.'
Write-Host '3. Delete github-secrets.txt after the secrets are stored safely.'
Write-Host '4. Never regenerate olympus-app-signing.jks after publishing v1.3.6.'
Write-Host '5. In Play App Signing choose to provide your own app-signing key; use olympus-app-signing.jks via the Play Console PEPK flow.'
