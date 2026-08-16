from pathlib import Path

p = Path('docs/index.html')
text = p.read_text(encoding='utf-8')


def replace_exact(old: str, new: str, expected: int = 1) -> None:
    global text
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'Expected {expected} matches, found {count}: {old!r}')
    text = text.replace(old, new)


# Avoid claiming universal camera compatibility. OPC details and firmware differ by model.
replace_exact(
    '"text": "Olympus View works with all Olympus and OM System cameras that support WiFi connectivity via the OPC (Olympus OPC Communication Protocol), including Olympus TG-6, OM System OM-1, and other WiFi-enabled models."',
    '"text": "Olympus View is designed for compatible Olympus and OM System WiFi cameras that expose the expected OPC interface. The project lists models including Olympus TG-6, TG-7, OM System OM-1, OM-1 Mark II, OM-5 and several E-M/PEN models; compatibility depends on the camera firmware and OPC endpoints."',
)

# English download cards: point to the actual downloadable archives.
replace_exact(
    '<a href="https://github.com/dpolarov/olympus-view-and-delete/tree/master/releases" class="download-card" target="_blank" rel="noopener">\n            <div class="download-icon">🪟</div>\n            <h3>Windows</h3>\n            <p>Portable EXE<br>No installation needed</p>\n        </a>',
    '<a href="https://raw.githubusercontent.com/dpolarov/olympus-view-and-delete/master/releases/OlympusView-windows.zip" class="download-card">\n            <div class="download-icon">🪟</div>\n            <h3>Windows</h3>\n            <p>Portable ZIP<br>Direct download</p>\n        </a>',
)
replace_exact(
    '<a href="https://github.com/dpolarov/olympus-view-and-delete/tree/master/releases" class="download-card" target="_blank" rel="noopener">\n            <div class="download-icon">🌐</div>\n            <h3>Web</h3>\n            <p>Open in browser<br>No installation</p>\n        </a>',
    '<a href="https://raw.githubusercontent.com/dpolarov/olympus-view-and-delete/master/releases/OlympusView-web.zip" class="download-card">\n            <div class="download-icon">🌐</div>\n            <h3>Web</h3>\n            <p>Web build ZIP<br>Run in browser</p>\n        </a>',
)
replace_exact(
    '<h3>Does it work without installing anything?</h3>\n            <p>Yes. The <strong>Web version</strong> works in any browser — no installation needed. Just connect your PC to the camera\'s WiFi hotspot and open the web app.</p>',
    '<h3>Is there a Web build?</h3>\n            <p>Yes. Download the <strong>Web ZIP</strong>, run the web build in a browser, and connect the PC to the camera\'s WiFi network. No native desktop installer is required.</p>',
)

# Russian download cards and FAQ.
replace_exact(
    '<a href="https://github.com/dpolarov/olympus-view-and-delete/tree/master/releases" class="download-card" target="_blank" rel="noopener">\n            <div class="download-icon">🪟</div>\n            <h3>Windows</h3>\n            <p>Portable EXE<br>Не требует установки</p>\n        </a>',
    '<a href="https://raw.githubusercontent.com/dpolarov/olympus-view-and-delete/master/releases/OlympusView-windows.zip" class="download-card">\n            <div class="download-icon">🪟</div>\n            <h3>Windows</h3>\n            <p>Portable ZIP<br>Прямая загрузка</p>\n        </a>',
)
replace_exact(
    '<a href="https://github.com/dpolarov/olympus-view-and-delete/tree/master/releases" class="download-card" target="_blank" rel="noopener">\n            <div class="download-icon">🌐</div>\n            <h3>Web</h3>\n            <p>Открыть в браузере<br>Без установки</p>\n        </a>',
    '<a href="https://raw.githubusercontent.com/dpolarov/olympus-view-and-delete/master/releases/OlympusView-web.zip" class="download-card">\n            <div class="download-icon">🌐</div>\n            <h3>Web</h3>\n            <p>Web ZIP<br>Запуск в браузере</p>\n        </a>',
)
replace_exact(
    '<h3>Работает ли приложение без установки?</h3>\n            <p>Да. <strong>Web-версия</strong> работает в любом браузере — установка не нужна. Подключите ПК к WiFi камеры и откройте веб-приложение.</p>',
    '<h3>Есть ли Web-версия?</h3>\n            <p>Да. Скачайте <strong>Web ZIP</strong>, запустите веб-сборку в браузере и подключите ПК к WiFi камеры. Нативный установщик для ПК не требуется.</p>',
)

# Ukrainian download cards.
replace_exact(
    '<a href="https://github.com/dpolarov/olympus-view-and-delete/tree/master/releases" class="download-card" target="_blank" rel="noopener">\n            <div class="download-icon">🪟</div>\n            <h3>Windows</h3>\n            <p>Portable EXE<br>Не потребує встановлення</p>\n        </a>',
    '<a href="https://raw.githubusercontent.com/dpolarov/olympus-view-and-delete/master/releases/OlympusView-windows.zip" class="download-card">\n            <div class="download-icon">🪟</div>\n            <h3>Windows</h3>\n            <p>Portable ZIP<br>Пряме завантаження</p>\n        </a>',
)
replace_exact(
    '<a href="https://github.com/dpolarov/olympus-view-and-delete/tree/master/releases" class="download-card" target="_blank" rel="noopener">\n            <div class="download-icon">🌐</div>\n            <h3>Web</h3>\n            <p>Відкрити у браузері<br>Без встановлення</p>\n        </a>',
    '<a href="https://raw.githubusercontent.com/dpolarov/olympus-view-and-delete/master/releases/OlympusView-web.zip" class="download-card">\n            <div class="download-icon">🌐</div>\n            <h3>Web</h3>\n            <p>Web ZIP<br>Запуск у браузері</p>\n        </a>',
)

p.write_text(text, encoding='utf-8')
print('Updated download links and FAQ compatibility wording.')
