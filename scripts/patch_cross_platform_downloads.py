from pathlib import Path
import re

REPO = "https://github.com/dpolarov/olympus-view-and-delete"
ANDROID = f"{REPO}/releases/latest/download/OlympusView-Android.apk"
WINDOWS = f"{REPO}/releases/latest/download/OlympusView-Windows.zip"
WEB = f"{REPO}/releases/latest/download/OlympusView-Web.zip"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


def patch(path: str, transform) -> None:
    p = Path(path)
    old = p.read_text(encoding="utf-8")
    new = transform(old)
    if new == old:
        raise SystemExit(f"{path}: no changes produced")
    p.write_text(new, encoding="utf-8")
    print(f"updated {path}")


def patch_html(text: str) -> str:
    old_windows = "https://raw.githubusercontent.com/dpolarov/olympus-view-and-delete/master/releases/OlympusView-windows.zip"
    old_web = "https://raw.githubusercontent.com/dpolarov/olympus-view-and-delete/master/releases/OlympusView-web.zip"
    wc = text.count(old_windows)
    bc = text.count(old_web)
    if wc != 3 or bc != 3:
        raise SystemExit(f"docs/index.html: expected 3 language links each, found windows={wc}, web={bc}")
    return text.replace(old_windows, WINDOWS).replace(old_web, WEB)


def patch_index_en(text: str) -> str:
    old = f"""### Windows

A portable Windows build is stored in the repository releases directory:

{REPO}/tree/master/releases

### Web

A web build is also stored in the repository releases directory. The computer must still be connected to the camera's WiFi network for camera access.

{REPO}/tree/master/releases
"""
    new = f"""### Windows

Latest portable Windows x64 build:

{WINDOWS}

### Web

Latest Web build ZIP. Extract it, serve the directory over local HTTP (the ZIP includes a README), and connect the computer to the camera's WiFi network before using Olympus View.

{WEB}
"""
    return replace_once(text, old, new, "docs/index.md downloads")


def patch_index_ru(text: str) -> str:
    old = f"""### Windows и Web

Сборки хранятся в каталоге releases репозитория:

{REPO}/tree/master/releases
"""
    new = f"""### Windows

Последняя portable-сборка Windows x64:

{WINDOWS}

### Web

Последняя Web-сборка ZIP. Распакуйте архив, запустите каталог через локальный HTTP-сервер (в архиве есть README) и подключите компьютер к WiFi камеры.

{WEB}
"""
    return replace_once(text, old, new, "docs/index.ru.md downloads")


def patch_index_uk(text: str) -> str:
    old = f"""### Windows і Web

Збірки зберігаються в каталозі releases репозиторію:

{REPO}/tree/master/releases
"""
    new = f"""### Windows

Остання portable-збірка Windows x64:

{WINDOWS}

### Web

Остання Web-збірка ZIP. Розпакуйте архів, запустіть каталог через локальний HTTP-сервер (в архіві є README) та підключіть комп'ютер до WiFi камери.

{WEB}
"""
    return replace_once(text, old, new, "docs/index.uk.md downloads")


def patch_llms(text: str) -> str:
    anchor = f"- [Android APK]({ANDROID}): Latest direct-install Android APK binary.\n"
    new = anchor + (
        f"- [Windows x64 ZIP]({WINDOWS}): Latest portable Windows desktop build.\n"
        f"- [Web ZIP]({WEB}): Latest static Flutter Web build with local HTTP run instructions.\n"
    )
    return replace_once(text, anchor, new, "docs/llms.txt downloads")


def patch_readme(text: str) -> str:
    replacements = {
        "Pre-built releases are in the `releases/` folder:": "Pre-built binaries are published with each GitHub Release:",
        "| Android  | `releases/OlympusView-Android.apk` |": f"| Android  | [OlympusView-Android.apk]({ANDROID}) |",
        "| Windows  | `releases/windows/olympus_flutter.exe` |": f"| Windows  | [OlympusView-Windows.zip]({WINDOWS}) |",
        "| Web      | `releases/web/` (open `index.html`) |": f"| Web      | [OlympusView-Web.zip]({WEB}) |",
        "Готові збірки знаходяться у папці `releases/`:": "Готові збірки публікуються в кожному GitHub Release:",
        "| Android   | `releases/OlympusView-Android.apk` |": f"| Android   | [OlympusView-Android.apk]({ANDROID}) |",
        "| Windows   | `releases/windows/olympus_flutter.exe` |": f"| Windows   | [OlympusView-Windows.zip]({WINDOWS}) |",
        "| Web       | `releases/web/` (відкрити `index.html`) |": f"| Web       | [OlympusView-Web.zip]({WEB}) |",
    }
    changed = 0
    for old, new in replacements.items():
        count = text.count(old)
        if count:
            text = text.replace(old, new)
            changed += count
    if changed < 4:
        raise SystemExit(f"README.md: too few release references updated ({changed})")
    return text


def patch_gitignore(text: str) -> str:
    old = "# Releases folder\n#/releases/"
    new = "# Generated release artifacts belong in GitHub Releases, never in Git.\n/releases/"
    return replace_once(text, old, new, ".gitignore releases")


patch("docs/index.html", patch_html)
patch("docs/index.md", patch_index_en)
patch("docs/index.ru.md", patch_index_ru)
patch("docs/index.uk.md", patch_index_uk)
patch("docs/llms.txt", patch_llms)
patch("README.md", patch_readme)
patch(".gitignore", patch_gitignore)
