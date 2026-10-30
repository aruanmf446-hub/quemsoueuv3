"""Prevent the rejected ornamental kit from becoming a menu dependency again."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SCOPES = ('scripts/menu', 'scripts/ui', 'scripts/skins', 'scripts/lobby',
          'scenes/menu', 'scenes/player', 'scenes/skins', 'scenes/lobby')
RETIRED = re.compile(r'res://assets/(?:ui/|processed/(?:frames|buttons|textures)/)')


def violations(root=ROOT):
    for scope in SCOPES:
        for path in sorted((root / scope).rglob('*')):
            if path.suffix not in {'.gd', '.tscn', '.tres'}:
                continue
            for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                if RETIRED.search(line):
                    yield f'{path.relative_to(root)}:{number}: {line.strip()}'


if __name__ == '__main__':
    errors = list(violations())
    if errors:
        print('Rejected ornamental menu assets:\n' + '\n'.join(errors))
        sys.exit(1)
    print('Menu design guard: OK')
