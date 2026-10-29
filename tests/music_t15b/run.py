"""Integração real T15B. Gera apenas PCM zerado e isola user:// de cada execução."""
import argparse, json, os, re, shutil, subprocess, tempfile, wave
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
parser.add_argument('--output', default='/tmp/qse-t15b-results')
parser.add_argument('--capture', action='store_true', help='Requer DISPLAY/OpenGL; captura o clique real a partir das Configurações.')
a = parser.parse_args()
root = Path(__file__).resolve().parents[2]
fixtures = root / 'assets/music/_local_test'
out = Path(a.output).resolve()
out.mkdir(parents=True, exist_ok=True)
if fixtures.exists():
    raise SystemExit('Pasta de fixtures já existe; mova/preserve seu conteúdo antes de rodar: ' + str(fixtures))
fixtures.mkdir()
results = []
try:
    with wave.open(str(fixtures / 'silence.wav'), 'wb') as f:
        f.setparams((1, 2, 8000, 0, 'NONE', 'not compressed'))
        f.writeframes(b'\0\0' * 8000 * 12)
    (fixtures / 'cover.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8" fill="#112233"/></svg>')
    engine = [a.godot, '--path', str(root)]
    targets = [
        ('import', engine + ['--headless', '--editor', '--import', '--quit']),
        ('flow', engine + ['--headless', '--script', 'res://tests/music_t15b/verify.gd']),
        ('playback', engine + ['--headless', '--script', 'res://tests/music_t15b/verify.gd', '--', '--local-music-test']),
        ('settings', engine + ['--headless', '--script', 'res://tests/settings_t14b/verify.gd']),
        ('audio', ['python3', str(root / 'tests/audio/run.py'), '--godot', a.godot]),
    ]
    if a.capture:
        targets.append(('capture', engine + ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--script', 'res://tests/music_t15b/verify.gd', '--', '--capture']))
    for name, command in targets:
        with tempfile.TemporaryDirectory(prefix='qse-t15b-' + name + '-') as user_data:
            env = os.environ.copy()
            for var, folder in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
                env[var] = str(Path(user_data) / folder)
                Path(env[var]).mkdir()
            r = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, timeout=180)
        log = r.stdout + r.stderr
        (out / (name + '.log')).write_text(log)
        passed = r.returncode == 0 and not re.search(r'(?:SCRIPT ERROR:|ERROR:|Parse Error:|FAIL )', log)
        results.append(dict(test=name, exit_code=r.returncode, passed=passed))
        print(name, 'PASS' if passed else 'FAIL', flush=True)
        if name == 'import' and not passed:
            break
finally:
    shutil.rmtree(fixtures)
    (out / 'results.json').write_text(json.dumps(results, indent=2))
raise SystemExit(0 if results and all(r['passed'] for r in results) else 1)
