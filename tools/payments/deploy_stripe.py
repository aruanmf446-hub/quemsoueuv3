"""Deploy only the two GAME payment functions. Does not set Stripe secrets or enable payments.

Requires the GAME management credential in the environment. Existing functions require
--update; default refuses replacement. Never reads CATALOG or CHAT credentials.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[2]
PROJECT = 'shuzporktifgiotvnpbz'
SLUGS = ('qse-coin-checkout', 'qse-stripe-webhook')


def call(path, method='GET', body=None, content_type='application/json'):
    request = urllib.request.Request(
        f'https://api.supabase.com/v1/projects/{PROJECT}{path}', data=body, method=method,
        headers={'Authorization': 'Bearer ' + os.environ['QSE_GAME_SUPABASE_MANAGEMENT_TOKEN'],
                 'Content-Type': content_type})
    try:
        with urllib.request.urlopen(request, timeout=55) as response:
            raw = response.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        raise SystemExit(f'GAME management HTTP {error.code}; operation failed. No response secrets logged.') from None


def bundle(slug):
    base = ROOT / 'supabase/game/functions'
    shared = (base / '_shared/stripe.js').read_text()
    handler = (base / slug / 'handler.js').read_text().splitlines()
    entry = (base / slug / 'index.ts').read_text().splitlines()
    assert handler[0].startswith('import ') and "../_shared/stripe.js" in handler[0]
    assert entry[0].startswith('import ') and "./handler.js" in entry[0]
    return (shared + '\n' + '\n'.join(handler[1:]) + '\n' + '\n'.join(entry[1:]) + '\n').encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--update', action='store_true')
    parser.add_argument('--bundle-dir', type=Path, help='Write local bundles only, no network or deployment')
    args = parser.parse_args()
    if args.bundle_dir:
        args.bundle_dir.mkdir(parents=True, exist_ok=True)
        for slug in SLUGS:
            (args.bundle_dir / (slug + '.ts')).write_bytes(bundle(slug))
        return
    existing = {item['slug'] for item in call('/functions')}
    if existing.intersection(SLUGS) and not args.update:
        raise SystemExit('Payment function already exists. Inspect it before using --update.')
    for slug in SLUGS:
        source = bundle(slug)
        metadata = json.dumps({'entrypoint_path': 'index.ts', 'verify_jwt': False, 'name': slug}).encode()
        boundary = 'qse-stripe-' + uuid.uuid4().hex
        body = (f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\nContent-Type: application/json\r\n\r\n'.encode()
                + metadata + f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="index.ts"\r\nContent-Type: application/typescript\r\n\r\n'.encode()
                + source + f'\r\n--{boundary}--\r\n'.encode())
        result = call('/functions/deploy?slug=' + slug, 'POST', body, 'multipart/form-data; boundary=' + boundary)
        print(json.dumps({'project': 'GAME', 'function': slug, 'status': result.get('status'),
                          'version': result.get('version'), 'verify_jwt': result.get('verify_jwt'),
                          'sha256': hashlib.sha256(source).hexdigest()}), flush=True)


if __name__ == '__main__':
    main()
