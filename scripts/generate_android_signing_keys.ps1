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
        "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }

    if ($candidates.Count -gt 0) { return $candidates[0] }
    throw 'keytool.exe was not found. Install/use the JDK bundled with Android Studio and run again.'
}

function Invoke-Keytool {
    param(
        [string]$Keytool,
        [string[]]$Arguments,
        [string]$FailureMessage
    )

    # Windows PowerShell turns native stderr into ErrorRecord objects. keytool
    # writes harmless informational/warning text to stderr, so temporarily use
    # Continue and judge success only by the native exit code.
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Keytool @Arguments 2>&1 | ForEach-Object { Write-Host $_ }
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($exitCode -ne 0) { throw $FailureMessage }
}

function Get-Sha256Fingerprint(
    [string]$Keytool,
    [string]$Keystore,
    [string]$StorePassword,
    [string]$Alias
) {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Keytool -list -v -storetype PKCS12 -keystore $Keystore -storepass $StorePassword -alias $Alias 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($exitCode -ne 0) { throw "Unable to inspect $Keystore" }
    $line = $output | Select-String -Pattern 'SHA256:' | Select-Object -First 1
    if (-not $line) { throw "SHA-256 fingerprint was not found for $Alias" }
    return (($line.Line -replace '^.*SHA256:\s*', '') -replace ':', '').Trim().ToLowerInvariant()
}

$keytool = Get-KeytoolPath
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $env:USERPROFILE '.olympus-view\signing'
$appKeystore = Join-Path $outDir 'olympus-app-signing.p12'
$uploadKeystore = Join-Path $outDir 'olympus-play-upload.p12'
$legacyAppKeystore = Join-Path $outDir 'olympus-app-signing.jks'
$legacyUploadKeystore = Join-Path $outDir 'olympus-play-upload.jks'
$appCert = Join-Path $outDir 'olympus-app-signing-cert.pem'
$uploadCert = Join-Path $outDir 'olympus-play-upload-cert.pem'
$secretsFile = Join-Path $outDir 'github-secrets.txt'
$recoveryFile = Join-Path $outDir 'signing-recovery.txt'
$keyProperties = Join-Path $root 'android\key.properties'

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$existingSigningFiles = @(
    $appKeystore,
    $uploadKeystore,
    $legacyAppKeystore,
    $legacyUploadKeystore,
    $appCert,
    $uploadCert,
    $secretsFile,
    $recoveryFile
) | Where-Object { Test-Path $_ }

if ($existingSigningFiles.Count -gt 0 -and -not $Force) {
    Write-Host 'Existing signing material was found:' -ForegroundColor Yellow
    $existingSigningFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ''
    Write-Host 'If this is the incomplete set from the failed first run, rerun with -Force.' -ForegroundColor Yellow
    Write-Host 'Do NOT use -Force after v1.3.6 has been published.' -ForegroundColor Yellow
    throw 'Refusing to overwrite existing signing material without -Force.'
}

if ($Force) {
    Write-Host '[cleanup] Removing existing pre-release signing material...'
    foreach ($path in @(
        $appKeystore,
        $uploadKeystore,
        $legacyAppKeystore,
        $legacyUploadKeystore,
        $appCert,
        $uploadCert,
        $secretsFile,
        $recoveryFile
    )) {
        if (Test-Path $path) { Remove-Item -Force $path }
    }
}

$appPassword = New-RandomSecret
$uploadPassword = New-RandomSecret
$appAlias = 'olympus-app-signing'
$uploadAlias = 'olympus-play-upload'
$dname = 'CN=Olympus View, OU=Android, O=Olympus View'

# Save generated passwords before invoking keytool. If a later command fails,
# the keys remain recoverable instead of leaving an unknown-password keystore.
@"
# Olympus View signing recovery data
# KEEP PRIVATE. This file is outside the repository.
APP_KEYSTORE=$appKeystore
APP_ALIAS=$appAlias
APP_PASSWORD=$appPassword
PLAY_UPLOAD_KEYSTORE=$uploadKeystore
PLAY_UPLOAD_ALIAS=$uploadAlias
PLAY_UPLOAD_PASSWORD=$uploadPassword
"@ | Set-Content -Encoding ASCII -Path $recoveryFile

Write-Host '[1/6] Generating long-lived production app-signing key (PKCS12)...'
Invoke-Keytool -Keytool $keytool -FailureMessage 'Failed to generate production app-signing key.' -Arguments @(
    '-genkeypair', '-v',
    '-keystore', $appKeystore, '-storetype', 'PKCS12',
    '-storepass', $appPassword, '-keypass', $appPassword,
    '-alias', $appAlias, '-keyalg', 'RSA', '-keysize', '4096', '-sigalg', 'SHA256withRSA',
    '-validity', '36500', '-dname', $dname, '-noprompt'
)

Write-Host '[2/6] Generating separate Google Play upload key (PKCS12)...'
Invoke-Keytool -Keytool $keytool -FailureMessage 'Failed to generate Google Play upload key.' -Arguments @(
    '-genkeypair', '-v',
    '-keystore', $uploadKeystore, '-storetype', 'PKCS12',
    '-storepass', $uploadPassword, '-keypass', $uploadPassword,
    '-alias', $uploadAlias, '-keyalg', 'RSA', '-keysize', '4096', '-sigalg', 'SHA256withRSA',
    '-validity', '36500', '-dname', $dname, '-noprompt'
)

Write-Host '[3/6] Exporting public certificates...'
Invoke-Keytool -Keytool $keytool -FailureMessage 'Failed to export app-signing certificate.' -Arguments @(
    '-exportcert', '-rfc', '-storetype', 'PKCS12',
    '-keystore', $appKeystore, '-storepass', $appPassword,
    '-alias', $appAlias, '-file', $appCert
)
Invoke-Keytool -Keytool $keytool -FailureMessage 'Failed to export Play upload certificate.' -Arguments @(
    '-exportcert', '-rfc', '-storetype', 'PKCS12',
    '-keystore', $uploadKeystore, '-storepass', $uploadPassword,
    '-alias', $uploadAlias, '-file', $uploadCert
)

Write-Host '[4/6] Reading certificate fingerprints...'
$appSha256 = Get-Sha256Fingerprint $keytool $appKeystore $appPassword $appAlias
$uploadSha256 = Get-Sha256Fingerprint $keytool $uploadKeystore $uploadPassword $uploadAlias
if ($appSha256 -eq $uploadSha256) { throw 'App-signing and Play upload certificates unexpectedly match.' }

Write-Host '[5/6] Creating local android/key.properties for GitHub/direct APK builds...'
$appPathForGradle = $appKeystore.Replace('\', '/')
@"
storeFile=$appPathForGradle
storePassword=$appPassword
keyAlias=$appAlias
keyPassword=$appPassword
"@ | Set-Content -Encoding ASCII -Path $keyProperties

Write-Host '[6/6] Preparing GitHub Actions secret values...'
$appB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($appKeystore))
$uploadB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($uploadKeystore))
@"
# Olympus View Android signing secrets
# KEEP THIS FILE PRIVATE. Delete it after copying the values to GitHub Actions secrets.

ANDROID_KEYSTORE_BASE64=$appB64
ANDROID_KEYSTORE_PASSWORD=$appPassword
ANDROID_KEY_ALIAS=$appAlias
ANDROID_KEY_PASSWORD=$appPassword
ANDROID_SIGNING_CERT_SHA256=$appSha256

PLAY_UPLOAD_KEYSTORE_BASE64=$uploadB64
PLAY_UPLOAD_KEYSTORE_PASSWORD=$uploadPassword
PLAY_UPLOAD_KEY_ALIAS=$uploadAlias
PLAY_UPLOAD_KEY_PASSWORD=$uploadPassword
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
Write-Host "Recovery data: $recoveryFile"
Write-Host ''
Write-Host 'IMPORTANT:'
Write-Host '1. Back up BOTH .p12 files in at least two protected locations.'
Write-Host '2. Put the values from github-secrets.txt into Repository -> Settings -> Secrets and variables -> Actions.'
Write-Host '3. Store the passwords in a password manager, then delete github-secrets.txt and signing-recovery.txt.'
Write-Host '4. Never regenerate olympus-app-signing.p12 after publishing v1.3.6.'
Write-Host '5. In Play App Signing, provide olympus-app-signing.p12 through the Play Console PEPK flow.'
