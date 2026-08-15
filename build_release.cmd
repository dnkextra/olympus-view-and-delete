@echo off
echo ========================================
echo  Olympus Flutter - Build All Releases
echo ========================================
echo.

set FLUTTER=C:\flutter\bin\flutter.bat
set PROJECT=C:\tmp\olympus_flutter
set RELEASES=%PROJECT%\releases

if not exist "%RELEASES%" mkdir "%RELEASES%"

echo [1/8] Building Android APK (sideload)...
call %FLUTTER% build apk --release --obfuscate --split-debug-info=build/symbols
if errorlevel 1 (echo FAILED: APK build & goto :end)

echo [2/8] Copying APK to releases...
copy /Y "%PROJECT%\build\app\outputs\flutter-apk\app-release.apk" "%RELEASES%\OlympusView.apk"

echo [3/8] Building Android App Bundle (Google Play)...
call %FLUTTER% build appbundle --release --obfuscate --split-debug-info=build/symbols
if errorlevel 1 (echo FAILED: AAB build & goto :end)

echo [4/8] Copying AAB to releases...
copy /Y "%PROJECT%\build\app\outputs\bundle\release\app-release.aab" "%RELEASES%\OlympusView.aab"

echo [5/8] Building Web...
call %FLUTTER% build web --release
if errorlevel 1 (echo FAILED: Web build & goto :end)

echo [6/8] Copying Web to releases...
if exist "%RELEASES%\web" rmdir /S /Q "%RELEASES%\web"
xcopy "%PROJECT%\build\web" "%RELEASES%\web\" /E /I /Q

echo [7/8] Building Windows...
call %FLUTTER% build windows --release
if errorlevel 1 (echo FAILED: Windows build & goto :end)

echo [8/8] Copying Windows to releases...
if exist "%RELEASES%\windows" rmdir /S /Q "%RELEASES%\windows"
xcopy "%PROJECT%\build\windows\x64\runner\Release" "%RELEASES%\windows\" /E /I /Q

echo.
echo ========================================
echo  Done! Files in releases:
echo ========================================
dir /S /B "%RELEASES%\OlympusView.apk"
dir /S /B "%RELEASES%\OlympusView.aab"
dir /S /B "%RELEASES%\windows\olympus_flutter.exe"
echo Web: %RELEASES%\web\index.html
echo Debug symbols: %PROJECT%\build\symbols (upload to Play Console for crash deobfuscation)
echo.

:end
pause
