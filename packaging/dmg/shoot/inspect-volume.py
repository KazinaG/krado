"""CI runner only. Read DS_Store and inspect candidate background files read-only."""
import pathlib
import subprocess
import sys
from ds_store import DSStore
mount = pathlib.Path(sys.argv[1])
subprocess.run(['ls', '-la', str(mount)], check=False)
try:
    with DSStore.open(str(mount / '.DS_Store'), 'r') as store:
        for record in store:
            if record.code in (b'bwsp', b'icvp', b'Iloc'):
                print(record.filename, record.code, repr(record.value), flush=True)
                if record.code == b'icvp':
                    value = record.value
                    if isinstance(value, dict):
                        print('backgroundImageAlias present?', bool(value.get('backgroundImageAlias')), flush=True)
except Exception as exc:
    print('DS_Store inspection:', exc, flush=True)
# Background aliases usually point into a hidden directory or hidden root file.
# Restrict recursion to hidden background containers, never scan app bundles.
candidates = []
for p in mount.iterdir():
    if p.is_file() and (p.name.startswith('.') or p.suffix.lower() in ('.png','.jpg','.jpeg','.tif','.tiff','.heic')):
        candidates.append(p)
    elif p.is_dir() and p.name.startswith('.') and 'background' in p.name.lower():
        candidates.extend(q for q in p.rglob('*') if q.is_file())
for p in candidates:
    if p.name == '.DS_Store':
        continue
    print('BACKGROUND CANDIDATE', p, flush=True)
    subprocess.run(['sips','-g','pixelWidth','-g','pixelHeight','-g','dpiWidth',str(p)], check=False)
    subprocess.run(['tiffutil','-info',str(p)], check=False)
    subprocess.run([sys.argv[2],str(p)], check=False)
