from pathlib import Path

p = Path('build_release.cmd')
s = p.read_text(encoding='utf-8')
old = r'''echo.
echo [1/7] Cleaning Flutter build cache...
rem This is intentional for release builds. A stale incremental AOT artifact can
rem otherwise produce a new Android manifest around an older libapp.so.
call "%FLUTTER%" clean
if errorlevel 1 goto :failed

rem Be explicit on Windows: stale .dart_tool/flutter_build or Android project
rem caches must not survive a release build even if a tool leaves them behind.
call "%PROJECT%\android\gradlew.bat" --stop >nul 2>nul
if exist "%PROJECT%\build" rmdir /S /Q "%PROJECT%\build"
if exist "%PROJECT%\.dart_tool" rmdir /S /Q "%PROJECT%\.dart_tool"
if exist "%PROJECT%\android\.gradle" rmdir /S /Q "%PROJECT%\android\.gradle"
if exist "%PROJECT%\build" (
  echo ERROR: build directory could not be removed.
  goto :failed
)
if exist "%PROJECT%\.dart_tool" (
  echo ERROR: .dart_tool directory could not be removed.
  goto :failed
)
'''
new = r'''echo.
echo [1/7] Stopping Gradle and clearing Flutter AOT cache...
rem Stop Gradle before asking Flutter to clean. On Windows, D8/R8/Gradle can
rem temporarily keep classes.dex open; that unrelated lock must not block a
rem release as long as the Dart AOT inputs/outputs are removed and verified.
call "%PROJECT%\android\gradlew.bat" --stop >nul 2>nul

call "%FLUTTER%" clean
if errorlevel 1 (
  echo WARNING: flutter clean could not remove every Gradle build file.
  echo          Continuing with strict targeted Flutter AOT cleanup.
)

rem These paths can contain stale Dart snapshots/libapp.so and therefore MUST
rem be removed. Old dex/resources elsewhere under build\ are safe to leave;
rem Gradle owns them and will rebuild what it needs.
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
'''
if old not in s:
    raise SystemExit('cleanup block not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
