from pathlib import Path

p = Path('docs/index.html')
text = p.read_text(encoding='utf-8')


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Expected exactly one match, found {count}: {old!r}')
    text = text.replace(old, new, 1)


replace_once(
    '    <link rel="canonical" href="https://dpolarov.github.io/olympus-view-and-delete/">\n',
    '    <link rel="canonical" href="https://dpolarov.github.io/olympus-view-and-delete/">\n'
    '    <link rel="alternate" type="text/markdown" href="https://dpolarov.github.io/olympus-view-and-delete/index.md">\n'
    '    <link rel="describedby" href="https://dpolarov.github.io/olympus-view-and-delete/llms.txt">\n',
)

replace_once(
    '      "codeRepository": "https://github.com/dpolarov/olympus-view-and-delete",\n',
    '      "sameAs": "https://github.com/dpolarov/olympus-view-and-delete",\n',
)

replace_once(
    '      "dateModified": "2026-08-16",\n      "license": "https://opensource.org/licenses/MIT",\n',
    '      "dateModified": "2026-08-16",\n'
    '      "isAccessibleForFree": true,\n'
    '      "releaseNotes": "https://github.com/dpolarov/olympus-view-and-delete/releases/tag/v1.3.6",\n',
)

replace_once(
    "  en: { htmlLang: 'en', title: 'Olympus View — WiFi File Manager for Olympus & OM System | Delete Photos, OI.Share Alternative', desc: 'Free open-source app to manage Olympus and OM System cameras via WiFi. Delete photos, batch download by date, filter RAW files. Works on Android, Windows and browser.' },",
    "  en: { htmlLang: 'en', title: 'Olympus View — WiFi File Manager for Olympus & OM System | Delete Photos, OI.Share Alternative', desc: 'Free app to manage Olympus and OM System cameras via WiFi. Delete photos, download in the background on Android, remember downloaded files, batch by date and filter RAW.' },",
)
replace_once(
    "  ru: { htmlLang: 'ru', title: 'Olympus View — управление камерой Olympus через WiFi с удалением фото | Альтернатива OI.Share', desc: 'Бесплатное приложение для управления камерами Olympus и OM System через WiFi. Удаляйте фото с камеры, массово скачивайте по датам, фильтруйте RAW. Android, Windows и браузер.' },",
    "  ru: { htmlLang: 'ru', title: 'Olympus View — управление камерой Olympus через WiFi с удалением фото | Альтернатива OI.Share', desc: 'Приложение для камер Olympus и OM System через WiFi: удаление фото, фоновое скачивание на Android, метки скачанных файлов, выбор по датам и RAW-фильтр.' },",
)
replace_once(
    "  uk: { htmlLang: 'uk', title: 'Olympus View — керування камерою Olympus через WiFi з видаленням фото | Альтернатива OI.Share', desc: 'Безкоштовний застосунок для керування камерами Olympus та OM System через WiFi. Видаляйте фото з камери, масово завантажуйте за датами, фільтруйте RAW. Android, Windows і браузер.' }",
    "  uk: { htmlLang: 'uk', title: 'Olympus View — керування камерою Olympus через WiFi з видаленням фото | Альтернатива OI.Share', desc: 'Застосунок для камер Olympus та OM System через WiFi: видалення фото, фонове завантаження на Android, позначки завантажених файлів, вибір за датою та RAW-фільтр.' }",
)

replace_once(
    ' &bull; <a href="privacy.html" style="color:var(--accent)">Privacy Policy</a></p>',
    ' &bull; <a href="privacy.html" style="color:var(--accent)">Privacy Policy</a>'
    ' &bull; <a href="index.md" style="color:var(--accent)">Markdown</a>'
    ' &bull; <a href="llms.txt" style="color:var(--accent)">llms.txt</a></p>',
)

p.write_text(text, encoding='utf-8')
print('Updated docs/index.html for LLM discovery and structured data.')
