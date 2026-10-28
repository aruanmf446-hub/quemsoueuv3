"""Frozen blob exceptions for reviewed evolution; never skip a changed file."""
import json
from pathlib import Path


def expected_blob(root, baseline, relative, original):
    manifest = json.loads((Path(root) / "data/integration/preservation.json").read_text())
    return manifest["baselines"].get(baseline, {}).get(relative, original)
