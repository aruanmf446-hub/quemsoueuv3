"""Fetch the public sample FBX into an isolated test stage, never the game assets."""
from pathlib import Path
import hashlib
import sys
import urllib.request

URL = 'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/models/fbx/Samba%20Dancing.fbx'
SHA256 = 'b9003ee562c87bf03051c3a502411b0808d3513f1d74a2011f7530d9f067069f'
stage = Path(sys.argv[1]).resolve()
root = Path(__file__).resolve().parents[2]
assert stage != root and (stage / '.iphone_web_fixture_stage').exists(), 'Use an isolated fixture stage.'
output = stage / 'tests/fbx_dance/source.fbx'
output.parent.mkdir(parents=True, exist_ok=True)
if output.exists() and hashlib.sha256(output.read_bytes()).hexdigest() == SHA256:
    print('Sample FBX already verified.')
else:
    with urllib.request.urlopen(URL, timeout=45) as response:
        data = response.read(8 * 1024 * 1024)
    assert hashlib.sha256(data).hexdigest() == SHA256, 'Upstream sample changed; inspect before using.'
    output.write_bytes(data)
    print('Sample FBX downloaded and verified:', len(data), 'bytes')
