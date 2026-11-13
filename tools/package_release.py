#!/usr/bin/env python3
"""Package already exported desktop builds, licenses and documentation."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parent.parent
VERSION = '0.1.0-alpha'
OUT = ROOT / 'builds/release'
OUT.mkdir(parents=True, exist_ok=True)
checksums = []
for platform, binary in [('linux', 'sonar.x86_64'), ('windows', 'sonar.exe')]:
    source = ROOT / 'builds' / platform / binary
    if not source.exists():
        raise SystemExit(f'Export missing: {source}')
    archive = OUT / f'SONAR-{VERSION}-{platform}-x86_64.zip'
    prefix = f'SONAR-{platform}/'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        bundle.write(source, prefix + binary)
        for filename in ['README.md', 'LICENSE']:
            bundle.write(ROOT / filename, prefix + filename)
        bundle.write(ROOT / 'assets/fonts/LICENSE.txt', prefix + 'licenses/fonts.txt')
        for document in sorted((ROOT / 'docs').rglob('*')):
            if document.is_file() and not document.name.endswith('.import'):
                bundle.write(document, prefix + document.relative_to(ROOT).as_posix())
        readme = f'''SONAR: ECHOES OF THE HOLLOW — {VERSION}

Décompressez tous les fichiers puis lancez {binary}.
Linux : si nécessaire, chmod +x sonar.x86_64.
Commencez par Entraînement > Tutoriel, puis essayez une partie 3v3.
ZQSD / WASD au choix dans Paramètres. Échap : pause. F : ping.
G / T : maintenir pour prévisualiser le gadget, relâcher pour déployer.
E : maintenir dans le cercle d'une arche pour s'extraire.

Alpha de production : voir docs/PRODUCTION_STATUS.md et TEST_REPORT.md.
Windows : build produit, validation native Windows encore nécessaire.
Sources et mises à jour : https://github.com/redairaqi08/game
'''
        bundle.writestr(prefix + 'LIRE_MOI.txt', readme)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    checksums.append(f'{digest}  {archive.name}')
    print(f'{archive.name}: {archive.stat().st_size:,} bytes')
(OUT / 'SHA256SUMS.txt').write_text('\n'.join(checksums) + '\n')
