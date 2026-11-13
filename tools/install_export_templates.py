#!/usr/bin/env python3
"""Install only desktop Godot templates from the official release ZIP using ranges.

Avoids downloading Android/iOS/Web toolchains (the full archive exceeds1GB).
Python standard library only. HTTPS certificate validation and ZIP CRC remain on.
"""
import argparse
import io
import os
from pathlib import Path
import urllib.request
import zipfile

VERSION = '4.6.3'
URL = f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz'

class RangeReader(io.RawIOBase):
    def __init__(self, url):
        self.url = url
        with urllib.request.urlopen(urllib.request.Request(url, method='HEAD'), timeout=60) as response:
            self.length = int(response.headers['Content-Length'])
        self.position = 0
        self.downloaded = 0

    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        return self.position

    def read(self, amount=-1):
        if amount < 0:
            amount = self.length - self.position
        amount = min(amount, self.length - self.position)
        if amount <= 0:
            return b''
        start = self.position
        end = start + amount - 1
        request = urllib.request.Request(self.url, headers={'Range': f'bytes={start}-{end}'})
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 206:
                raise RuntimeError('Release host did not honor HTTP byte ranges; full archive download intentionally skipped.')
            data = response.read(amount)
        if len(data) != amount:
            raise IOError(f'Truncated archive range ({len(data)}/{amount})')
        self.position += amount
        self.downloaded += amount
        return data

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=Path)
    parser.add_argument('--platform', choices=['linux', 'windows', 'both'], default='both')
    args = parser.parse_args()
    base = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
    destination = args.destination or base / 'godot/export_templates' / f'{VERSION}.stable'
    destination.mkdir(parents=True, exist_ok=True)
    files = ['version.txt']
    if args.platform in ('linux', 'both'):
        files += ['linux_debug.x86_64', 'linux_release.x86_64']
    if args.platform in ('windows', 'both'):
        files += ['windows_debug_x86_64.exe', 'windows_release_x86_64.exe']
    source = RangeReader(URL)
    with zipfile.ZipFile(source) as archive:
        for filename in files:
            target = destination / filename
            if target.exists():
                print('Already installed:', filename)
                continue
            data = archive.read('templates/' + filename)
            target.write_bytes(data)
            if filename.startswith('linux'):
                target.chmod(0o755)
            print(f'Installed {filename} ({len(data):,} bytes)')
    print(f'Downloaded {source.downloaded:,} bytes from the official release; destination: {destination}')

if __name__ == '__main__':
    main()
