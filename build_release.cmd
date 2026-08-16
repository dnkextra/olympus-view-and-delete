@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "PROJECT=%~dp0"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"
set "FLUTTER=C:\flutter\bin\flutter.bat"
set "RELEASES=%PROJECT%\releases"
set "BUILT_APK=%PROJECT%\build\app\outputs\flutter-apk\app-github-release.apk"
set "RELEASE_APK=%RELEASES%\OlympusView-Android.apk"
set "KEY_PROPERTIES=%PROJECT%\android\key.properties"

cd /d "%PROJECT%" || goto :failed

if not exist "%FLUTTER%" (
  where flutter >nul 2>nul
  if errorlevel 1 (
    echo ERROR: Flutter was not found at C:\flutter\bin\flutter.bat or in PATH.
    goto :failed
  )
  set "FLUTTER=flutter"
)

where git >nul 2>nul
if errorlevel 1 (
  echo ERROR: git.exe was not found in PATH.
  goto :failed
)

set "GIT_BRANCH="
for /f "delims=" %%A in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set "GIT_BRANCH=%%A"
if not defined GIT_BRANCH (
  echo ERROR: Could not determine the current Git branch.
  goto :failed
)
if /I not "!GIT_BRANCH!"=="master" (
  echo ERROR: build_release.cmd only creates publishable APKs from master.
  echo Current branch: !GIT_BRANCH!
  echo.
  echo Switch to the current release source first:
  echo   git switch master
  echo   git pull --ff-only
  goto :failed
)

set "GIT_COMMIT="
for /f "delims=" %%A in ('git rev-parse --short HEAD 2^>nul') do set "GIT_COMMIT=%%A"

set "BUILD_TIME_UTC="
for /f "delims=" %%A in ('powershell -NoProfile -Command "[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')" 2^>nul') do set "BUILD_TIME_UTC=%%A"
if not defined BUILD_TIME_UTC set "BUILD_TIME_UTC=unknown"

set "BUILD_FLUTTER_VERSION=unknown"
for /f "tokens=2" %%A in ('call "%FLUTTER%" --version 2^>nul ^| findstr /B /C:"Flutter "') do set "BUILD_FLUTTER_VERSION=%%A"

set "PUBSPEC_VERSION="
for /f "tokens=2" %%A in ('findstr /B /C:"version:" "%PROJECT%\pubspec.yaml"') do set "PUBSPEC_VERSION=%%A"
if not defined PUBSPEC_VERSION (
  echo ERROR: Could not read the version from pubspec.yaml.
  goto :failed
)

set "BUILD_NAME="
set "BUILD_NUMBER="
for /f "tokens=1,2 delims=+" %%A in ("!PUBSPEC_VERSION!") do (
  set "BUILD_NAME=%%A"
  set "BUILD_NUMBER=%%B"
)
if not defined BUILD_NAME goto :bad_version
if not defined BUILD_NUMBER goto :bad_version

goto :version_ok

:bad_version
echo ERROR: Invalid pubspec version: !PUBSPEC_VERSION!
echo Expected format: 1.2.3+4
goto :failed

:version_ok
if not exist "%RELEASES%" mkdir "%RELEASES%"

echo ========================================
echo  Olympus View - GitHub Android Release
echo ========================================
echo Source branch : !GIT_BRANCH!
echo Source commit : !GIT_COMMIT!
echo App version   : !BUILD_NAME! (build !BUILD_NUMBER!)
echo Build time UTC: !BUILD_TIME_UTC!
echo Flutter       : !BUILD_FLUTTER_VERSION!
echo.

rem v1.3.6+ uses the long-lived production app-signing key. Never fall back to
rem the Android debug keystore: doing so would create an incompatible update.
if not exist "%KEY_PROPERTIES%" (
  echo ERROR: Production signing configuration is missing:
  echo   %KEY_PROPERTIES%
  echo.
  echo Generate the production app-signing key and Play upload key once with:
  echo   powershell -ExecutionPolicy Bypass -File scripts\generate_android_signing_keys.ps1
  echo.
  echo Do NOT use %%USERPROFILE%%\.android\debug.keystore for release builds.
  goto :failed
)

findstr /I /C:"debug.keystore" "%KEY_PROPERTIES%" >nul
if not errorlevel 1 (
  echo ERROR: android\key.properties points to a debug keystore.
  echo Production releases from v1.3.6 onward must use olympus-app-signing.jks.
  goto :failed
)

echo [signing] Using explicit production android\key.properties

echo.
echo [1/7] Stopping Gradle and clearing Flutter AOT cache...
call "%PROJECT%\android\gradlew.bat" --stop >nul 2>nul

call "%FLUTTER%" clean
if errorlevel 1 (
  echo WARNING: flutter clean could not remove every Gradle build file.
  echo          Continuing with strict targeted Flutter AOT cleanup.
)

if exist "%PROJECT%\.dart_tool\flutter_build" rmdir /S /Q "%PROJECT%\.dart_tool\flutter_build"
if exist "%PROJECT%\build\app\intermediates\flutter\githubRelease" rmdir /S /Q "%PROJECT%\build\app\intermediates\flutter\githubRelease"
if exist "%PROJECT%\build\app\intermediates\merged_native_libs\githubRelease" rmdir /S /Q "%PROJECT%\build\app\intermediates\merged_native_libs\githubRelease"
if exist "%PROJECT%\build\app\intermediates\stripped_native_libs\githubRelease" rmdir /S /Q "%PROJECT%\build\app\intermediates\stripped_native_libs\githubRelease"
if exist "%BUILT_APK%" del /Q "%BUILT_APK%"

if exist "%PROJECT%\.dart_tool\flutter_build" (
  echo ERROR: Flutter AOT cache is still locked:
  echo   %PROJECT%\.dart_tool\flutter_build
  goto :failed
)
if exist "%PROJECT%\build\app\intermediates\flutter\githubRelease" (
  echo ERROR: Old GitHub Flutter intermediates are still locked:
  echo   %PROJECT%\build\app\intermediates\flutter\githubRelease
  goto :failed
)
if exist "%BUILT_APK%" (
  echo ERROR: Old GitHub APK could not be removed:
  echo   %BUILT_APK%
  goto :failed
)

echo.
echo [2/7] Resolving dependencies...
call "%FLUTTER%" pub get
if errorlevel 1 goto :failed

echo.
echo [3/7] Removing stale release copy...
if exist "%RELEASE_APK%" del /Q "%RELEASE_APK%"

echo.
echo [4/7] Building signed GitHub APK !BUILD_NAME! build !BUILD_NUMBER!...
call "%FLUTTER%" build apk --flavor github --release --build-name !BUILD_NAME! --build-number !BUILD_NUMBER! --dart-define=OLYMPUS_BUILD_TIME_UTC=!BUILD_TIME_UTC! --dart-define=OLYMPUS_GIT_COMMIT=!GIT_COMMIT! --dart-define=OLYMPUS_FLUTTER_VERSION=!BUILD_FLUTTER_VERSION!
if errorlevel 1 goto :failed
if not exist "%BUILT_APK%" (
  echo ERROR: Flutter reported success but the expected APK was not created:
  echo   %BUILT_APK%
  goto :failed
)

echo.
echo [5/7] Verifying packaged Dart AOT metadata...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT%\scripts\verify_apk_dart_metadata.ps1" -ApkPath "%BUILT_APK%" -ExpectedCommit "!GIT_COMMIT!" -ExpectedBuildTime "!BUILD_TIME_UTC!"
if errorlevel 1 (
  echo ERROR: Packaged Dart code does not match this build.
  echo        Refusing to copy a potentially stale APK.
  goto :failed
)

echo.
echo [6/7] Verifying APK manifest version...
set "AAPT="
where aapt >nul 2>nul
if not errorlevel 1 (
  for /f "delims=" %%A in ('where aapt') do if not defined AAPT set "AAPT=%%A"
)
if not defined AAPT (
  if defined ANDROID_HOME (
    for /f "delims=" %%A in ('dir /b /s /a-d "%ANDROID_HOME%\build-tools\aapt.exe" 2^>nul') do set "AAPT=%%A"
  )
)
if not defined AAPT (
  if defined ANDROID_SDK_ROOT (
    for /f "delims=" %%A in ('dir /b /s /a-d "%ANDROID_SDK_ROOT%\build-tools\aapt.exe" 2^>nul') do set "AAPT=%%A"
  )
)
if not defined AAPT (
  if exist "%LOCALAPPDATA%\Android\Sdk\build-tools" (
    for /f "delims=" %%A in ('dir /b /s /a-d "%LOCALAPPDATA%\Android\Sdk\build-tools\aapt.exe" 2^>nul') do set "AAPT=%%A"
  )
)

if defined AAPT (
  set "BADGING_FILE=%TEMP%\olympus-view-apk-badging.txt"
  "!AAPT!" dump badging "%BUILT_APK%" > "!BADGING_FILE!" 2>nul
  if errorlevel 1 (
    echo ERROR: aapt could not inspect the built APK.
    goto :failed
  )
  findstr /C:"versionCode='!BUILD_NUMBER!'" "!BADGING_FILE!" >nul
  if errorlevel 1 (
    echo ERROR: APK versionCode does not match requested build !BUILD_NUMBER!.
    type "!BADGING_FILE!" | findstr /B /C:"package:"
    del /Q "!BADGING_FILE!" >nul 2>nul
    goto :failed
  )
  findstr /C:"versionName='!BUILD_NAME!'" "!BADGING_FILE!" >nul
  if errorlevel 1 (
    echo ERROR: APK versionName does not match requested version !BUILD_NAME!.
    type "!BADGING_FILE!" | findstr /B /C:"package:"
    del /Q "!BADGING_FILE!" >nul 2>nul
    goto :failed
  )
  for /f "delims=" %%A in ('findstr /B /C:"package:" "!BADGING_FILE!"') do echo [verify] %%A
  del /Q "!BADGING_FILE!" >nul 2>nul
) else (
  echo WARNING: aapt.exe was not found; manifest version verification was skipped.
  echo          Flutter still receives explicit --build-name/--build-number values.
)

echo.
echo [7/7] Copying APK...
copy /Y "%BUILT_APK%" "%RELEASE_APK%" >nul
if errorlevel 1 goto :failed

echo.
echo ========================================
echo  Android release file
echo ========================================
echo Version: !BUILD_NAME! (build !BUILD_NUMBER!)
echo Build UTC: !BUILD_TIME_UTC!
echo Commit: !GIT_COMMIT!
echo Flutter: !BUILD_FLUTTER_VERSION!
echo APK: %RELEASE_APK%
echo.
echo NOTE: Google Play AAB is intentionally not built by this script.
echo       It must use the separate Play upload key via the "Google Play AAB" workflow.
set "EXIT_CODE=0"
goto :done

:failed
echo.
echo FAILED: Release build did not complete.
set "EXIT_CODE=1"

:done
echo.
pause
exit /b %EXIT_CODE%
