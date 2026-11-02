"""Inspect actual release outputs: one ABI per APK, AOT code and real sizes."""
import json
import os
from pathlib import Path
from zipfile import ZipFile

folder = Path('build/app/outputs/flutter-apk')
rows = []
for abi in ('arm64-v8a', 'armeabi-v7a', 'x86_64'):
    path = folder / f'app-{abi}-release.apk'
    with ZipFile(path) as archive:
        names = set(archive.namelist())
        architectures = {name.split('/')[1] for name in names if name.startswith('lib/') and name.endswith('.so')}
        assert architectures == {abi}, (path, architectures)
        assert f'lib/{abi}/libapp.so' in names, path
        assert f'lib/{abi}/libflutter.so' in names, path
        assert not any(name.endswith('kernel_blob.bin') for name in names), path
    rows.append({'abi': abi, 'filename': path.name, 'sizeBytes': path.stat().st_size,
                 'sizeMB': round(path.stat().st_size / 1_000_000, 2)})

(folder / 'apk-sizes.json').write_text(json.dumps(rows, indent=2), encoding='utf8')
summary = '| APK | ABI | MB (actual APK) |\n|---|---|---:|\n'
for row in rows:
    print(f"APK_SIZE {row['abi']}: {row['sizeBytes']} bytes ({row['sizeMB']} MB)")
    summary += f"| {row['filename']} | {row['abi']} | {row['sizeMB']} |\n"
if os.environ.get('GITHUB_STEP_SUMMARY'):
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf8') as output:
        output.write(summary)
