from pathlib import Path

for path in [
    Path('.github/workflows/flutter-ci.yml'),
    Path('.github/workflows/release.yml'),
]:
    text = path.read_text(encoding='utf-8')
    old = '    runs-on: windows-latest\n'
    new = '    # permission_handler_windows 0.2.x still uses MSVC experimental coroutines;\n    # VS2026 turns that deprecation into a hard error. Keep release builds on\n    # the supported VS2022 toolchain until the permission plugin is upgraded.\n    runs-on: windows-2022\n'
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one windows-latest runner, found {count}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')
    print(f'updated {path}')
