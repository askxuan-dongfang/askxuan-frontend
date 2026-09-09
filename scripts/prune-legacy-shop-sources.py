#!/usr/bin/env python3
"""After a verified migration, archive and remove only the moved legacy source files.
Usage: python3 prune-legacy-shop-sources.py /opt/askxuan/frontend /opt/askxuan/backups/RELEASE
"""
import json, shutil, sys
from pathlib import Path
root, backup = (Path(value).resolve() for value in sys.argv[1:])
manifest = json.loads((root / 'scripts/admin-migration-manifest.json').read_text())
apis = json.loads((root / 'scripts/commerce-api-baseline.json').read_text())
relative = [Path('views') / item['view'] for item in manifest] + [Path('api') / name for name in apis]
old = root / 'apps/web-shop-admin/src'
new = root / 'apps/web-platform-admin/src/commerce'
for path in relative:
    assert '..' not in path.parts and (new / path).is_file(), f'Migration target missing: {path}'
count = 0
for path in relative:
    source = old / path
    if source.is_file():
        target = backup / 'legacy-shop-source' / path
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            shutil.copy2(source, target)
        source.unlink()
        count += 1
print(f'Archived and removed {count} moved source files; unified implementations remain intact')
