from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'Expected block not found in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'CHANGELOG.md',
    '## [1.3.7] - 2026-08-27\n\n### Added',
    '''## [1.3.7] - 2026-08-27

### Android signing compatibility
- Users already on **1.3.6 or newer** can update normally. Users on **1.3.5 or older** still need the one-time uninstall/reinstall introduced by 1.3.6 because those older APKs were signed with the temporary legacy certificate.

### Added''',
)

replace_once(
    'CHANGELOG.md',
    '- Extracted magic numbers into named constants: camera request/download/probe timeouts, mode-switch delay, disk/memory cache caps, thumbnail concurrency, history size, preview resolution) live in `lib/services/service_config.dart` as plain Dart constants, with no Flutter UI dependency.',
    '- Extracted magic numbers into named constants: camera request/download/probe timeouts, mode-switch delay, disk/memory cache caps, thumbnail concurrency, batch-flush interval, QR success delay, preview load timeout, preview keep-neighbors and preview image size; removed duplicate constants and resolved the `_keepNeighbors` TODO',
)

replace_once(
    '.github/workflows/release.yml',
    'default: "v1.3.6"',
    'default: "v1.3.7"',
)
replace_once(
    '.github/workflows/release.yml',
    '${INPUT_TAG:-v1.3.6}',
    '${INPUT_TAG:-v1.3.7}',
)

replace_once('docs/index.html', '"softwareVersion": "1.3.6"', '"softwareVersion": "1.3.7"')
replace_once('docs/index.html', '"dateModified": "2026-08-16"', '"dateModified": "2026-08-27"')
replace_once(
    'docs/index.html',
    '"releaseNotes": "https://github.com/dpolarov/olympus-view-and-delete/releases/tag/v1.3.6"',
    '"releaseNotes": "https://github.com/dpolarov/olympus-view-and-delete/releases/tag/v1.3.7"',
)

replace_once(
    'docs/index.html',
    '''        <div class="changelog-version">
            <h3>v1.3.6 — August 16, 2026</h3>''',
    '''        <div class="changelog-version">
            <h3>v1.3.7 — August 27, 2026</h3>
            <h4>Camera-transfer reliability &amp; stronger integration tests</h4>
            <ul>
                <li><strong>Fixed thumbnail fetch races</strong> — disk-cache lookup now finishes before a camera network slot is consumed.</li>
                <li><strong>Bounded full-screen preview cache</strong> during rapid paging, even when swiping faster than neighbor preloading.</li>
                <li><strong>Safer downloads</strong> — non-200 camera responses are rejected instead of being saved as files.</li>
                <li><strong>Failed/truncated transfers never poison caches</strong>, verified with HTTP 500, garbage-body and mid-transfer failure scenarios.</li>
                <li><strong>On-device integration tests</strong> now exercise a fake Olympus camera over real TCP sockets, filesystem cache persistence and thumbnail concurrency.</li>
                <li>Version: <strong>1.3.7+16</strong>.</li>
            </ul>
        </div>
        <div class="changelog-version">
            <h3>v1.3.6 — August 16, 2026</h3>''',
)

replace_once(
    'docs/index.html',
    '''        <div class="changelog-version">
            <h3>v1.3.6 — 16 серпня 2026</h3>''',
    '''        <div class="changelog-version">
            <h3>v1.3.7 — 27 серпня 2026</h3>
            <h4>Надійніша передача з камери та розширені інтеграційні тести</h4>
            <ul>
                <li><strong>Виправлено гонку завантаження мініатюр</strong> — перевірка дискового кешу завершується до зайняття мережевого слота камери.</li>
                <li><strong>Обмежено кеш повноекранного перегляду</strong> під час швидкого гортання.</li>
                <li><strong>Безпечніше завантаження</strong> — відповіді камери з HTTP-кодом, відмінним від 200, більше не зберігаються як файли.</li>
                <li><strong>Помилкові та обірвані передачі не потрапляють у кеш</strong>.</li>
                <li><strong>Інтеграційні тести на Android</strong> перевіряють фальшиву Olympus-камеру через реальні TCP-з'єднання, файловий кеш і паралельність мініатюр.</li>
                <li>Версія: <strong>1.3.7+16</strong>.</li>
            </ul>
        </div>
        <div class="changelog-version">
            <h3>v1.3.6 — 16 серпня 2026</h3>''',
)

replace_once(
    'docs/index.html',
    '''        <div class="changelog-version">
            <h3>v1.3.6 — 16 августа 2026</h3>''',
    '''        <div class="changelog-version">
            <h3>v1.3.7 — 27 августа 2026</h3>
            <h4>Надёжнее передача с камеры и расширенные интеграционные тесты</h4>
            <ul>
                <li><strong>Исправлена гонка загрузки миниатюр</strong> — проверка дискового кэша завершается до занятия сетевого слота камеры.</li>
                <li><strong>Ограничен кэш полноэкранного превью</strong> при быстром листании.</li>
                <li><strong>Безопаснее скачивание</strong> — ответы камеры с HTTP-кодом не 200 больше не сохраняются как файлы.</li>
                <li><strong>Ошибочные и оборванные передачи не попадают в кэш</strong>.</li>
                <li><strong>Интеграционные тесты на Android</strong> проверяют фальшивую Olympus-камеру через реальные TCP-соединения, файловый кэш и параллельность миниатюр.</li>
                <li>Версия: <strong>1.3.7+16</strong>.</li>
            </ul>
        </div>
        <div class="changelog-version">
            <h3>v1.3.6 — 16 августа 2026</h3>''',
)
