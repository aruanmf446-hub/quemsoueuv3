"""Isolated Godot tests. Generates only zero-valued PCM, never music or shipped tracks."""
import argparse, json, os, pathlib, shutil, subprocess, tempfile, wave
p = argparse.ArgumentParser()
p.add_argument('--godot', required=True)
a = p.parse_args()
root = pathlib.Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='qse-t11-') as folder:
    d = pathlib.Path(folder)
    env = os.environ.copy()
    for key, leaf in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
        path = d / leaf
        path.mkdir()
        env[key] = str(path)
    for name in ['scripts/audio/menu_music.gd', 'data/music/catalog.json', 'tests/audio/test_menu_music.gd']:
        target = d / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / name, target)
    (d / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="T11 isolated audio tests"\n')
    assets = d / 'assets/music'
    assets.mkdir(parents=True)
    with wave.open(str(assets / 'silence.wav'), 'wb') as wav:
        wav.setparams((1, 2, 8000, 0, 'NONE', 'not compressed'))
        wav.writeframes(b'\0\0' * 16000)
    (assets / 'cover.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8" fill="black"/></svg>')
    base = dict(title='Technical silence fixture', artist='Test harness', audio='res://assets/music/silence.wav', cover='res://assets/music/cover.svg', enabled=True, license=dict(status='approved', scope='main_menu', reference='test-only-silence', starts_at=0, ends_at=4102444800))
    tracks = []
    for id in ['a', 'disabled', 'expired', 'pending', 'future', 'missing', 'b']:
        t = json.loads(json.dumps(base)); t['id'] = id
        if id == 'disabled': t['enabled'] = False
        if id == 'expired': t['license']['ends_at'] = 1
        if id == 'pending': t['license']['status'] = 'pending'
        if id == 'future': t['license']['starts_at'] = 4102444700
        if id == 'missing': t['audio'] = 'res://assets/music/missing.wav'
        tracks.append(t)
    (d / 'tests/audio/catalog.json').write_text(json.dumps(dict(version=1, fade_seconds=0.05, tracks=tracks)))
    (d / 'tests/audio/invalid.json').write_text('{broken')
    for args in [['--editor', '--import', '--quit'], ['--script', 'res://tests/audio/test_menu_music.gd']]:
        r = subprocess.run([a.godot, '--headless', '--path', str(d), *args], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
        print(r.stdout)
        if r.returncode or 'SCRIPT ERROR' in r.stdout or 'FAIL ' in r.stdout:
            raise SystemExit(1)
