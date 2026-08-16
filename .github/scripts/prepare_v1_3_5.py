from pathlib import Path
import re

# Bump package and fallback version metadata.
pubspec = Path('pubspec.yaml')
pubspec_text = pubspec.read_text(encoding='utf-8')
pubspec_text, count = re.subn(
    r'^version:\s*1\.3\.4\+13\s*$',
    'version: 1.3.5+14',
    pubspec_text,
    count=1,
    flags=re.M,
)
if count != 1:
    raise RuntimeError('Could not bump pubspec version to 1.3.5+14')
pubspec.write_text(pubspec_text, encoding='utf-8')

version_file = Path('lib/version.dart')
version_text = version_file.read_text(encoding='utf-8')
version_text = version_text.replace("const String appVersion = '1.3.4';", "const String appVersion = '1.3.5';")
version_text = version_text.replace("const String appBuild = '13';", "const String appBuild = '14';")
if "appVersion = '1.3.5'" not in version_text or "appBuild = '14'" not in version_text:
    raise RuntimeError('Could not bump lib/version.dart')
version_file.write_text(version_text, encoding='utf-8')

# Add a compact public test-release entry. The APK is production-signed and is
# intentionally a normal release so /releases/latest exposes it to v1.3.4.
changelog = Path('CHANGELOG.md')
text = changelog.read_text(encoding='utf-8')
if '## [1.3.5] - 2026-08-16' not in text:
    marker = '# Changelog\n\n'
    if not text.startswith(marker):
        raise RuntimeError('Unexpected CHANGELOG.md header')
    release = '''## [1.3.5] - 2026-08-16

### Added
- **Updater end-to-end test release**: a normal public GitHub release so installed `1.3.4+13` GitHub builds can exercise the complete in-app update path against a real newer version.
- **Updater regression tests** cover numeric version comparison, `1.3.2 -> 1.3.4`, same-version rejection, exact `OlympusView-Android.apk` asset selection, missing-APK rejection and release-note normalization.

### Changed
- Version bumped to **1.3.5+14**. Application behavior is otherwise the same as 1.3.4; this release exists primarily to verify download and installation through the built-in GitHub updater.

'''
    text = marker + release + text[len(marker):]
    changelog.write_text(text, encoding='utf-8')

# Update public site metadata and prepend localized changelog blocks.
index_path = Path('docs/index.html')
html = index_path.read_text(encoding='utf-8')
html = re.sub(r'"softwareVersion":\s*"[^"]+"', '"softwareVersion": "1.3.5"', html, count=1)
html = re.sub(r'"dateModified":\s*"[^"]+"', '"dateModified": "2026-08-16"', html, count=1)

blocks = {
    'changelog-en': '''        <div class="changelog-version">
            <h3>v1.3.5 — August 16, 2026</h3>
            <h4>Updater end-to-end test release</h4>
            <ul>
                <li><strong>Public updater test release</strong> — installed GitHub build 1.3.4 can now detect, download and install a real newer version through the built-in updater</li>
                <li><strong>Updater regression tests</strong> cover version comparison, exact APK asset selection, missing APK handling and release-note parsing</li>
                <li>Version: <strong>1.3.5+14</strong>; application behavior is otherwise the same as 1.3.4</li>
            </ul>
        </div>\n''',
    'changelog-uk': '''        <div class="changelog-version">
            <h3>v1.3.5 — 16 серпня 2026</h3>
            <h4>Наскрізний тест автооновлення</h4>
            <ul>
                <li><strong>Публічний тестовий реліз</strong> — встановлена GitHub-версія 1.3.4 може знайти, завантажити та встановити реальну новішу версію через вбудоване оновлення</li>
                <li><strong>Регресійні тести updater</strong> перевіряють порівняння версій, точний вибір APK, відсутність APK та release notes</li>
                <li>Версія: <strong>1.3.5+14</strong>; в іншому поведінка застосунку така сама, як у 1.3.4</li>
            </ul>
        </div>\n''',
    'changelog-ru': '''        <div class="changelog-version">
            <h3>v1.3.5 — 16 августа 2026</h3>
            <h4>Сквозной тест автообновления</h4>
            <ul>
                <li><strong>Публичный тестовый релиз</strong> — установленная GitHub-версия 1.3.4 теперь может обнаружить, скачать и установить реальную более новую версию через встроенное обновление</li>
                <li><strong>Регрессионные тесты updater</strong> проверяют сравнение версий, точный выбор APK, отсутствие APK и разбор release notes</li>
                <li>Версия: <strong>1.3.5+14</strong>; в остальном поведение приложения такое же, как в 1.3.4</li>
            </ul>
        </div>\n''',
}

for marker, block in blocks.items():
    if f'<h3>v1.3.5' in html[html.find(f'id="{marker}"'):html.find(f'id="{marker}"') + 1500]:
        continue
    pattern = rf'(<h2 id="{marker}">.*?</h2>\s*<div class="changelog">\s*)'
    html, count = re.subn(pattern, lambda match: match.group(1) + block, html, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f'Could not prepend {marker} block')

index_path.write_text(html, encoding='utf-8')
