from pathlib import Path

APP_SHA = '0d4e347b38ed19a5152f165facc3ba479e29d8c3a61c38d810f938357ace2d25'
UPLOAD_SHA = 'f295455a262877c7cfded9b9fde6228fbab59bdac23336508ffe2db45bdc4c4d'


def replace_required(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'missing expected text in {path}: {old!r}')
    p.write_text(text.replace(old, new), encoding='utf-8')

# Public certificate fingerprints belong in source control, not GitHub Secrets.
release = Path('.github/workflows/release.yml')
text = release.read_text(encoding='utf-8')
text = text.replace(
    '  LEGACY_DEBUG_CERT_SHA256: "3786a41c932c63183fc36dd388cb6be397775392d3bf6e7f4fb16dc28cae841e"\n',
    '  LEGACY_DEBUG_CERT_SHA256: "3786a41c932c63183fc36dd388cb6be397775392d3bf6e7f4fb16dc28cae841e"\n'
    f'  PRODUCTION_APP_CERT_SHA256: "{APP_SHA}"\n',
)
text = text.replace(
    '          EXPECTED_CERT_SHA256: ${{ secrets.ANDROID_SIGNING_CERT_SHA256 }}',
    '          EXPECTED_CERT_SHA256: ${{ env.PRODUCTION_APP_CERT_SHA256 }}',
)
release.write_text(text, encoding='utf-8')

play = Path('.github/workflows/play-build.yml')
text = play.read_text(encoding='utf-8')
text = text.replace(
    '  LEGACY_DEBUG_CERT_SHA256: "3786a41c932c63183fc36dd388cb6be397775392d3bf6e7f4fb16dc28cae841e"\n',
    '  LEGACY_DEBUG_CERT_SHA256: "3786a41c932c63183fc36dd388cb6be397775392d3bf6e7f4fb16dc28cae841e"\n'
    f'  PRODUCTION_APP_CERT_SHA256: "{APP_SHA}"\n'
    f'  PLAY_UPLOAD_CERT_SHA256: "{UPLOAD_SHA}"\n',
)
text = text.replace(
    '          EXPECTED_CERT_SHA256: ${{ secrets.PLAY_UPLOAD_CERT_SHA256 }}',
    '          EXPECTED_CERT_SHA256: ${{ env.PLAY_UPLOAD_CERT_SHA256 }}',
)
text = text.replace(
    '          APP_SIGNING_CERT_SHA256: ${{ secrets.ANDROID_SIGNING_CERT_SHA256 }}',
    '          APP_SIGNING_CERT_SHA256: ${{ env.PRODUCTION_APP_CERT_SHA256 }}',
)
play.write_text(text, encoding='utf-8')

# The generated secret file should contain only private/secret values.
gen = Path('scripts/generate_android_signing_keys.ps1')
text = gen.read_text(encoding='utf-8')
text = text.replace('ANDROID_SIGNING_CERT_SHA256=$appSha256\n\n', '')
text = text.replace('PLAY_UPLOAD_CERT_SHA256=$uploadSha256\n', '')
gen.write_text(text, encoding='utf-8')

# Documentation and release notes.
docs = Path('docs/GOOGLE_PLAY.md')
text = docs.read_text(encoding='utf-8')
text = text.replace('| `ANDROID_SIGNING_CERT_SHA256` | pinned production certificate fingerprint |\n', '')
text = text.replace('| `PLAY_UPLOAD_CERT_SHA256` | pinned Play upload certificate fingerprint |\n', '')
text = text.replace(
    'The GitHub release workflow rejects the old debug certificate and rejects a production certificate whose SHA-256 does not match `ANDROID_SIGNING_CERT_SHA256`. The Play workflow separately verifies `PLAY_UPLOAD_CERT_SHA256` and rejects using the production app-signing key as the upload key.',
    f'The public production certificate SHA-256 `{APP_SHA}` is pinned directly in the GitHub release workflow. The public Play upload certificate SHA-256 `{UPLOAD_SHA}` is pinned directly in the Play workflow. The workflows also reject the legacy debug certificate and reject using the production app-signing key as the Play upload key.',
)
text = text.replace('private JKS', 'private PKCS12')
text = text.replace('JKS files', 'PKCS12 files')
text = text.replace('JKS.', 'PKCS12 file.')
text = text.replace('JKS ', 'PKCS12 ')
text = text.replace('`olympus-app-signing.jks`', '`olympus-app-signing.p12`')
text = text.replace('`olympus-play-upload.jks`', '`olympus-play-upload.p12`')
docs.write_text(text, encoding='utf-8')

change = Path('CHANGELOG.md')
text = change.read_text(encoding='utf-8')
text = text.replace(
    'The release workflow verifies the production certificate SHA-256 stored in GitHub Secrets.',
    f'The release workflow pins and verifies the production certificate SHA-256 `{APP_SHA}`.',
)
change.write_text(text, encoding='utf-8')

build = Path('build_release.cmd')
text = build.read_text(encoding='utf-8')
text = text.replace('must use olympus-app-signing.jks.', 'must use olympus-app-signing.p12.')
build.write_text(text, encoding='utf-8')

print('Pinned production app certificate:', APP_SHA)
print('Pinned Play upload certificate:', UPLOAD_SHA)
