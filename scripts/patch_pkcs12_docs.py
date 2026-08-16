from pathlib import Path

path = Path('docs/GOOGLE_PLAY.md')
text = path.read_text()
replacements = {
    'olympus-app-signing.jks': 'olympus-app-signing.p12',
    'olympus-play-upload.jks': 'olympus-play-upload.p12',
    'both JKS files': 'both PKCS12 files',
    'private JKS': 'private PKCS12 keystore',
    'JKS backups': 'PKCS12 backups',
    'production app-signing JKS': 'production app-signing PKCS12 keystore',
    'dedicated Play upload JKS': 'dedicated Play upload PKCS12 keystore',
}
for old, new in replacements.items():
    text = text.replace(old, new)
path.write_text(text)
