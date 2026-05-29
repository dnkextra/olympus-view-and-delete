# Changelog

## [Unreleased]

## [1.3.1] - 2026-05-29

### Added
- **In-app language selection**: a language picker in the app bar lets you switch the UI between System, English, Русский and Українська at runtime; the choice is persisted across launches (`LocaleController` + `SharedPreferences`) and drives `MaterialApp.locale`

## [1.3.0] - 2026-05-29

### Added
- **Unified logging** (`AppLogger`): cross-platform logger built on `dart:developer` with `debug/info/warning/error` levels; release builds suppress logs below `warning`
- **Centralised service tuning** (`lib/services/service_config.dart`): named constants for network timeouts, cache/memory limits, connection-history size and preview resolution (no Flutter UI dependency)
- **In-memory thumbnail cache byte cap** (`kMaxMemThumbBytes`, 32 MiB): the thumbnail LRU now bounds RAM by total bytes in addition to entry count, so a few unusually large thumbnails can't exhaust memory; covered by new `thumbnail_manager_test.dart`
- **Network-error test coverage** (`camera_api_network_test.dart`): `CameraApi.listImages`/`deleteFile`/`deleteFiles` now tested against 404s, timeouts, connection failures, malformed records and corrupt FAT dates via an injectable `http.Client`
- **Localization tests** (`l10n_test.dart`): verify key parity across `en`/`ru`/`uk` ARB files, no orphan/empty translations, placeholder consistency, and that every supported locale resolves
- **Shared test helpers** (`test/helpers/test_helpers.dart`): `FakePathProvider` and `fixedResponseClient` extracted from duplicated mock-init code in the disk-cache and preview-screen tests

### Changed
- Replaced silently swallowed `catch (_) {}` blocks across services, screens and dialogs with logged handlers that capture the error and stack trace
- Extracted magic numbers into named constants: camera request/download/probe timeouts, mode-switch delay, disk/memory cache caps, thumbnail concurrency, batch-flush interval, QR success delay, preview load timeout, preview keep-neighbors and preview image size; removed duplicate constants and resolved the `_keepNeighbors` TODO
- Unified filename sanitisation into a single `sanitizeFilename` (`lib/services/filename_sanitizer.dart`), replacing the duplicate copies in `camera_api` and both file savers
- Extracted shared `_showSnack` / `_confirm` helpers in `HomeScreen` (removed duplicated SnackBar and confirmation-dialog code in download/delete handlers) and a shared `_itemDecoration` in `PhotoGrid`
- Stricter linting in `analysis_options.yaml`: `avoid_print` (as error), `use_build_context_synchronously`, `unawaited_futures`, `cancel_subscriptions`, `close_sinks`, `prefer_final_locals`, `directives_ordering`
- Fire-and-forget futures are now explicitly marked with `unawaited(...)`; imports sorted per `directives_ordering`
- Thumbnail fetch timeout now uses the shared `kCameraRequestTimeout` constant instead of an inline literal
- `CameraApi` accepts an optional injected `http.Client` (`CameraApi({client})`) for testability; production behaviour is unchanged
- Upgraded dependencies to their latest compatible versions (`media_scanner`, `shared_preferences`, `url_launcher` and transitive packages)
- Updated the Android toolchain to satisfy the refreshed AndroidX dependencies: `compileSdk`/`targetSdk` 35 → 36, Android Gradle Plugin 8.6.0 → 8.9.1, Gradle wrapper 8.7 → 8.11.1, NDK 26.1 → 28.2

### Fixed
- Preview screen download/delete icon tooltips now read "Download"/"Delete" instead of the all-caps action labels

## [1.2.0] - 2026-04-17

### Added
- **Test Suite**: 61 unit and widget tests covering caching, deletion, paging, QR decoding and connection history
- **Dependency Injection**: Photo preview screen accepts optional `CameraApi` and `http.Client` for testability

### Changed
- Disk cache LRU index writes are now debounced (fewer `SharedPreferences` writes while browsing)
- Hardened filename sanitization for downloaded photos (path traversal, NUL, control chars, Windows reserved names)
- Connection history saves are serialized to prevent race conditions under rapid writes

### Fixed
- Crash (`RangeError`) when deleting the last photo from the preview screen
- Race condition when the disk image cache was accessed before full initialization
- Release APK signing configuration

## [1.1.0] - 2026-04-06

### Added
- **Photo Preview**: Full-screen image viewer with swipe navigation and pinch-to-zoom
- **Preview Download/Delete**: Download or delete photos directly from preview screen (delete with confirmation)
- **Image Preloading**: Preload ±2 neighbor images for smooth swiping in preview
- **Disk Image Cache**: Persistent LRU cache (150 images) for thumbnails and previews across sessions
- **Connection History**: Save and recall previously connected cameras
- **Auto-Connect**: Automatically connect to last used camera on startup
- **Saved Cameras List**: Quick reconnect from error screen without rescanning QR
- **Status Messages**: Detailed connection progress (checking camera, connecting WiFi, loading files...)
- **Version Info**: App version displayed in About dialog

### Changed
- Retry camera connection up to 3 times after WiFi switch (1s delay)
- WiFi connection from saved cameras happens directly without navigating to QR screen
- Loading screen shows context-aware messages instead of generic "Connecting..."

### Fixed
- Error screen content centered horizontally and vertically
- Saved cameras list no longer shifts left when empty

## [1.0.0] - 2026-03-15

### Initial Release
- Connect to Olympus cameras via WiFi (QR code scan or manual SSID/password)
- Browse photos in grid or list view
- Filter photos by date range
- Batch select, download, and delete files
- RAW/ORF file toggle
- Download progress dialog with per-file tracking
- Delete progress dialog with per-file tracking
- Progressive file list loading
- Thumbnail caching (in-memory)
- Android and Web support
