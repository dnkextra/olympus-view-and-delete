from pathlib import Path
import re

CHANGELOG_BLOCK = """## [1.3.6] - 2026-08-16

### Important — one-time reinstall for 1.3.5 and older
- **Android signing certificate changed** from the temporary legacy debug certificate to the permanent production app-signing certificate. Android cannot update across unrelated signing certificates, so users of **1.3.5 and older must uninstall Olympus View and install 1.3.6 once**. Future GitHub APK updates will then work normally without another reinstall.
- Uninstalling the old build clears Olympus View's local settings and downloaded-file marker history. It does **not** delete photos already saved on the phone or files on the camera.

### Added
- **Visible app-update progress**: the GitHub build shows APK bytes/total and percent directly in Olympus View instead of disappearing into an opaque background download.
- **Update network status and recovery**: paused downloads clearly show when Android is waiting for internet; failed downloads can be retried and active downloads can be cancelled.
- **Install from inside the app**: when the APK reaches `DownloadManager.STATUS_SUCCESSFUL`, Olympus View opens the Android installer and also keeps an **Install** button available as a fallback even when notifications are disabled.
- **Select downloaded files**: selection mode now has a green `download_done` action that selects every currently visible file carrying the persistent green downloaded marker, making it easy to delete already-copied files from the camera.
- **Production signing setup tool**: `scripts/generate_android_signing_keys.ps1` generates a long-lived production app-signing key plus a separate Google Play upload key and prepares the required GitHub Actions secret values locally.

### Changed
- Camera auto-connect is suppressed while an application update is downloading so connecting to a camera Wi-Fi network without internet cannot silently stall the APK download.
- Notification permission is no longer required to start an app update; in-app progress and installation controls remain available without notifications.
- GitHub release builds now require an explicit production keystore and refuse the legacy debug certificate. The release workflow verifies the production certificate SHA-256 stored in GitHub Secrets.
- Google Play AAB builds use and verify a **separate upload key**. The production app-signing key is intended to be supplied to Play App Signing so GitHub and Play installations share the same final signing identity.
- Version set to **1.3.6+15**.

### Fixed
- Starting an in-app update no longer leaves the user with no visible indication of whether the APK is downloading, paused, failed or ready to install.
- Auto-connecting to the camera can no longer steal internet connectivity while an APK update is active.

"""

DOC_BLOCKS = {
    "en": """        <div class="changelog-version">
            <h3>v1.3.6 — August 16, 2026</h3>
            <h4>Updater reliability, downloaded-file cleanup &amp; production signing</h4>
            <ul>
                <li><strong>One-time reinstall required for v1.3.5 and older</strong> — v1.3.6 switches from the temporary legacy debug signing certificate to the permanent production certificate. Uninstall the old Olympus View and install v1.3.6 once; future GitHub updates will work normally.</li>
                <li><strong>Local settings and green-marker history reset on that uninstall</strong>; photos already saved on the phone and files on the camera are not affected.</li>
                <li><strong>Visible update progress</strong> with downloaded/total MB and percent, explicit waiting-for-internet status, retry/cancel controls and an in-app Install button.</li>
                <li><strong>Camera auto-connect pauses while an app update is active</strong>, preventing camera Wi-Fi without internet from stalling the APK download.</li>
                <li><strong>Select downloaded</strong> — a green selection-mode button selects every file carrying the persistent green downloaded marker so they can be deleted from the camera in one batch.</li>
                <li><strong>Production signing</strong> — GitHub APK releases now require the permanent app-signing key; Google Play uses a separate upload key while Play App Signing receives the same production signing identity.</li>
                <li>Version: <strong>1.3.6+15</strong>.</li>
            </ul>
        </div>
""",
    "ru": """        <div class="changelog-version">
            <h3>v1.3.6 — 16 августа 2026</h3>
            <h4>Надёжное обновление, выбор скачанных файлов и production-подпись</h4>
            <ul>
                <li><strong>Для v1.3.5 и старше нужна одноразовая переустановка</strong> — в v1.3.6 временный debug-сертификат заменён постоянным production-сертификатом. Удалите старый Olympus View и один раз установите v1.3.6; последующие обновления с GitHub снова будут ставиться поверх приложения.</li>
                <li><strong>При этой переустановке сбросятся локальные настройки и история зелёных отметок</strong>; уже сохранённые на телефоне фотографии и файлы на камере не затрагиваются.</li>
                <li><strong>Видимый прогресс обновления</strong>: скачано/всего МБ и проценты, статус ожидания интернета, повтор/отмена и кнопка установки прямо в приложении.</li>
                <li><strong>Автоподключение к камере приостанавливается на время обновления</strong>, чтобы Wi-Fi камеры без интернета не останавливал загрузку APK.</li>
                <li><strong>Выделить скачанные</strong> — новая зелёная кнопка в режиме выбора выделяет все файлы с сохранённой зелёной отметкой, после чего их можно удалить с камеры одной операцией.</li>
                <li><strong>Production-подпись</strong> — GitHub APK теперь подписываются постоянным app-signing ключом; для Google Play используется отдельный upload key, а в Play App Signing передаётся тот же production app-signing key.</li>
                <li>Версия: <strong>1.3.6+15</strong>.</li>
            </ul>
        </div>
""",
    "uk": """        <div class="changelog-version">
            <h3>v1.3.6 — 16 серпня 2026</h3>
            <h4>Надійне оновлення, вибір завантажених файлів і production-підпис</h4>
            <ul>
                <li><strong>Для v1.3.5 і старіших потрібне одноразове перевстановлення</strong> — у v1.3.6 тимчасовий debug-сертифікат замінено постійним production-сертифікатом. Видаліть старий Olympus View і один раз встановіть v1.3.6; наступні оновлення з GitHub знову встановлюватимуться поверх застосунку.</li>
                <li><strong>Під час цього перевстановлення скинуться локальні налаштування та історія зелених позначок</strong>; уже збережені на телефоні фотографії та файли на камері не зачіпаються.</li>
                <li><strong>Видимий прогрес оновлення</strong>: завантажено/всього МБ і відсотки, статус очікування інтернету, повтор/скасування та кнопка встановлення прямо в застосунку.</li>
                <li><strong>Автопідключення до камери призупиняється на час оновлення</strong>, щоб Wi-Fi камери без інтернету не зупиняв завантаження APK.</li>
                <li><strong>Виділити завантажені</strong> — нова зелена кнопка в режимі вибору виділяє всі файли зі збереженою зеленою позначкою, після чого їх можна видалити з камери однією операцією.</li>
                <li><strong>Production-підпис</strong> — GitHub APK тепер підписуються постійним app-signing ключом; для Google Play використовується окремий upload key, а в Play App Signing передається той самий production app-signing key.</li>
                <li>Версія: <strong>1.3.6+15</strong>.</li>
            </ul>
        </div>
""",
}

PLAY_SIGNING = """## Important: permanent signing model from v1.3.6

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
powershell -ExecutionPolicy Bypass -File .\\scripts\\generate_android_signing_keys.ps1
```

The script creates private signing material under `%USERPROFILE%\\.olympus-view\\signing\\`, writes `android/key.properties` for local GitHub/direct release builds, and creates a temporary `github-secrets.txt` containing the values needed for GitHub Actions.

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

"""


def patch_changelog():
    path = Path("CHANGELOG.md")
    text = path.read_text()
    if "## [1.3.6]" not in text:
        text = text.replace("# Changelog\n\n", "# Changelog\n\n" + CHANGELOG_BLOCK, 1)
    path.write_text(text)


def patch_index():
    path = Path("docs/index.html")
    html = path.read_text()
    html = html.replace('"softwareVersion": "1.3.5"', '"softwareVersion": "1.3.6"')
    for lang, block in DOC_BLOCKS.items():
        pattern = re.compile(rf'(<h2 id="changelog-{lang}">.*?</h2>\s*<div class="changelog">\s*)', re.S)
        match = pattern.search(html)
        if not match:
            raise RuntimeError(f"changelog marker not found for {lang}")
        if "v1.3.6" not in html[match.end():match.end() + 1600]:
            html = html[:match.end()] + block + html[match.end():]
    path.write_text(html)


def patch_play_docs():
    path = Path("docs/GOOGLE_PLAY.md")
    text = path.read_text()
    start = text.index("## Important: two signing channels")
    end = text.index("## 3. Build the Google Play bundle")
    text = text[:start] + PLAY_SIGNING + text[end:]
    text = text.replace(
        "2. Configure Play App Signing and let Google protect the app-signing key.\n3. Register/use the upload key created above.",
        "2. Configure Play App Signing, choose to provide your own app-signing key, and securely upload `olympus-app-signing.jks` using the PEPK instructions shown by Play Console.\n3. Register the separate `olympus-play-upload` certificate as the upload key.",
    )
    path.write_text(text)


patch_changelog()
patch_index()
patch_play_docs()
