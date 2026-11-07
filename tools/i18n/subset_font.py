"""Regenerate the licensed UI fallback: python3 tools/i18n/subset_font.py original.otf.
Requires fontTools; source and license are documented in assets/fonts/README.md.
"""
import json
import sys
from pathlib import Path
from fontTools import subset
root = Path(__file__).resolve().parents[2]
text = '日本語简体中文Русский'
for path in (root / 'data/ui').glob('*.json'):
    values = json.loads(path.read_text())
    text += ''.join(values) + ''.join(str(value) for value in values.values())
options = subset.Options()
options.name_IDs = ['*']
options.name_legacy = True
options.name_languages = ['*']
font = subset.load_font(sys.argv[1], options)
selection = subset.Subsetter(options=options)
selection.populate(text=text, unicodes=list(range(32, 127)) + list(range(0x400, 0x500)))
selection.subset(font)
subset.save_font(font, str(root / 'assets/fonts/qse-interface-fallback.otf'), options)
