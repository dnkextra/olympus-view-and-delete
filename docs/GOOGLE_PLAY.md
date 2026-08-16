# Publishing Olympus View on Google Play

This document describes the Play-specific release path. It is intentionally separate from the GitHub APK release path.

## Important: permanent signing model from v1.3.6

Releases through `v1.3.5` used a temporary legacy Android debug certificate. Starting with **v1.3.6**, Olympus View intentionally switches once to a permanent production signing identity.

Users of `v1.3.5` and older direct APKs must uninstall the old app and install `v1.3.6` once because Android does not allow an APK signed by an unrelated certificate to replace the installed package. After that one-time migration, normal GitHub self-updates work again.

### Recommended cross-store model

Use **two different private keys**:

1. `olympus-app-signing.jks` — the long-lived **production app-signing key**. GitHub/direct APK releases are signed with this key. When enrolling the new Play listing in Play App Signing, choose **Change app signing key / provide your own key** and securely provide this same key through the Play Console PEPK flow. This keeps the final APK signing certificate identical for GitHub and Google Play distributions.
2. `olympus-play-upload.jks` — a separate **Google Play upload key**. GitHub Actions uses this key only to sign the AAB uploaded to Play. Google verifies the uploader and then signs delivered APKs with the production app-signing key held by Play App Signing.

Do not use the old debug certificate for either role. Do not commit either private JKS to Git.

Google recommends keeping the upload key separate from the app-signing key. The upload key can be reset through Play if it is lost or compromised; the app-signing identity is the durable identity users' Android devices trust for updates.

## 1. Generate both permanent keys locally

From PowerShell at the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\generate_android_signing_keys.ps1
```

The script creates private signing material under `%USERPROFILE%\.olympus-view\signing\`, writes `android/key.properties` for local GitHub/direct release builds, and creates a temporary `github-secrets.txt` containing the values needed for GitHub Actions.

**Immediately make at least two protected backups of both JKS files.** Never regenerate `olympus-app-signing.jks` after publishing v1.3.6.

## 2. Configure GitHub Actions secrets

Repository -> Settings -> Secrets and variables -> Actions.

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | production app-signing JKS for GitHub APK/AAB releases |
| `ANDROID_KEYSTORE_PASSWORD` | app-signing keystore password |
| `ANDROID_KEY_ALIAS` | `olympus-app-signing` |
| `ANDROID_KEY_PASSWORD` | app-signing private-key password |
| `ANDROID_SIGNING_CERT_SHA256` | pinned production certificate fingerprint |
| `PLAY_UPLOAD_KEYSTORE_BASE64` | dedicated Play upload JKS |
| `PLAY_UPLOAD_KEYSTORE_PASSWORD` | Play upload keystore password |
| `PLAY_UPLOAD_KEY_ALIAS` | `olympus-play-upload` |
| `PLAY_UPLOAD_KEY_PASSWORD` | Play upload private-key password |
| `PLAY_UPLOAD_CERT_SHA256` | pinned Play upload certificate fingerprint |

Delete `github-secrets.txt` after the values are stored in GitHub and your password manager. Keep the JKS backups offline/protected.

The GitHub release workflow rejects the old debug certificate and rejects a production certificate whose SHA-256 does not match `ANDROID_SIGNING_CERT_SHA256`. The Play workflow separately verifies `PLAY_UPLOAD_CERT_SHA256` and rejects using the production app-signing key as the upload key.

## 3. Build the Google Play bundle

GitHub Actions -> `Google Play AAB` -> `Run workflow`.

The workflow:

1. restores the Play upload key only inside the ephemeral runner;
2. runs `flutter analyze`;
3. runs the test suite;
4. builds a release APK and checks 16 KB page-size compatibility;
5. builds the release Android App Bundle;
6. uploads `OlympusView-GooglePlay.aab` as a workflow artifact;
7. removes the temporary signing files.

Do not upload the GitHub-release APK to Play. Upload the AAB produced by `Google Play AAB`.

## 4. Android configuration already prepared

The project currently uses:

```text
targetSdk 36
compileSdk 36
AGP 8.10.1
Gradle 8.11.1
JDK 17
NDK 28.2.13676358
```

CI also checks native libraries for 16 KB page-size compatibility.

Android permissions are scoped for current Play requirements:

- `NEARBY_WIFI_DEVICES` on Android 13+ with `neverForLocation`;
- `ACCESS_FINE_LOCATION` only through Android 12L / API 32 for legacy Wi-Fi APIs;
- no broad storage permission on Android 10+;
- `WRITE_EXTERNAL_STORAGE` only through Android 9 / API 28;
- downloaded photos use Android MediaStore on Android 10+;
- application backup is disabled because locally stored camera credentials are sensitive.

## 5. Privacy Policy

Use this public URL in Play Console after GitHub Pages deploys the merged documentation:

```text
https://dpolarov.github.io/olympus-view-and-delete/privacy.html
```

The same Privacy Policy is linked from the application's About dialog.

## 6. Data Safety — important ML Kit disclosure

Do not answer the Data Safety form with a blanket "no data collected".

The app itself does not upload photos, QR contents, Wi-Fi passwords, SSIDs, or physical location to an Olympus View backend. However, Android QR scanning is implemented with Google ML Kit through `mobile_scanner`.

Google's ML Kit disclosure documentation says that ML Kit may collect technical data for diagnostics and usage analytics, including:

- device information;
- application/package and version information;
- per-installation/device-or-other identifiers;
- performance metrics;
- API configuration;
- feature events and error codes.

Google states that the QR/image input and recognition result are processed on-device and are not sent to Google. Google also states that the listed ML Kit telemetry is encrypted in transit and is not shared by ML Kit with third parties.

When completing the Play form, compare the current form categories with the current ML Kit disclosure documentation. At minimum, review the categories covering:

- **App info and performance / Diagnostics**;
- **Device or other IDs**;
- purposes related to diagnostics and usage analytics.

Do not declare physical location as collected by Olympus View: the legacy location permission exists only because Android <= 12L ties certain Wi-Fi APIs to location permission, and Olympus View does not derive or transmit physical location.

## 7. App content declarations

Review these in Play Console -> Policy and programs -> App content:

- Privacy Policy: provide the URL above.
- Ads: Olympus View contains no advertising SDK; answer according to the shipped build.
- App access: no account/login is required.
- Target audience: choose the age groups the app is actually intended for. Do not select child age groups unless the app is intentionally designed for children and you are prepared to meet Families requirements.
- Content rating: complete the IARC questionnaire accurately.
- Data Safety: complete it using the ML Kit notes above and the behavior of all dependencies in the final AAB.

## 8. Store listing materials

Prepare before production review:

- app name: `Olympus View`;
- short description;
- full description;
- 512x512 Play Store icon;
- feature graphic 1024x500;
- Android phone screenshots;
- support/contact email in the developer profile / store listing;
- privacy policy URL;
- category (Photography is the natural fit, but choose based on the final listing).

Be explicit in the listing that Olympus View is an **unofficial** application and is not affiliated with Olympus / OM System / OM Digital Solutions.

## 9. Versioning

The current Flutter version is read from `pubspec.yaml` in the form:

```text
version: major.minor.patch+versionCode
```

Every AAB uploaded to the same Play application must use a version code larger than every version code previously uploaded there.

Before the first Play production candidate, bump the version intentionally, for example:

```text
version: 1.4.0+6
```

Do not reuse a Play version code after it has been uploaded.

## 10. First Play Console upload

For a new Play application:

1. Create the application in Play Console using the existing Android package ID `com.flynew.photomanager` unless you intentionally decide to start a different package identity.
2. Configure Play App Signing, choose to provide your own app-signing key, and securely upload `olympus-app-signing.jks` using the PEPK instructions shown by Play Console.
3. Register the separate `olympus-play-upload` certificate as the upload key.
4. Start with Internal testing.
5. Upload `OlympusView-GooglePlay.aab`.
6. Resolve all automated pre-launch / policy warnings.
7. Test install and core camera flows from the Play-delivered build.
8. Move to Closed/Open testing or Production when the Play build is verified.

## 11. Release checks before production

- `flutter analyze` is clean.
- all Flutter tests pass.
- Android APK/AAB builds pass on GitHub Actions.
- 16 KB page-size compatibility check passes.
- QR permission flow tested on Android 13+.
- camera reconnect tested on Android 13+.
- photo download tested on Android 10+ via MediaStore.
- Android 9 legacy storage permission path tested if Android 9 support matters.
- Privacy Policy URL is publicly reachable without login.
- Data Safety matches the actual final AAB and all bundled SDKs.
- Play pre-launch report has no blocking crash/ANR/accessibility issues.
