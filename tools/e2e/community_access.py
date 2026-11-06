#!/usr/bin/env python3
"""Login and read-only deck checks using the existing GitHub QA accounts.
Never creates accounts, decks, claims, reports or rooms. Never prints credentials.
"""
import json
import os
from pathlib import Path
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
CONFIG = json.loads((ROOT / 'data/backend/client.json').read_text())
URL = CONFIG['url'].rstrip('/')
assert URL == 'https://shuzporktifgiotvnpbz.supabase.co'
KEY = CONFIG['publishable_key']
RESULTS = []


def request(path, body, token=None):
    headers = {'apikey': KEY, 'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode(),
                                 method='POST', headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, None
    except (urllib.error.URLError, ValueError):
        return 0, None


for role in ['OWNER', 'READER', 'R1']:
    row = {'role': role}
    email = os.environ.get('QSE_TEST_' + role + '_EMAIL')
    password = os.environ.get('QSE_TEST_' + role + '_PASSWORD')
    if not email or not password:
        row['status'] = 'missing_credentials'
    else:
        status, session = request('/auth/v1/token?grant_type=password',
                                  {'email': email, 'password': password})
        if status != 200 or not isinstance(session, dict) or not session.get('access_token'):
            row.update(status='login_failed', http_status=status)
        else:
            token = session['access_token']
            checks = [
                ('inventory', 'qse_community_inventory', {}, 'items'),
                ('community', 'qse_community_decks', {'p_query': None, 'p_theme': None,
                 'p_sort': 'recent', 'p_limit': 1, 'p_cursor': None}, 'items'),
                ('duel_catalog', 'qse_duel_decks', {}, 'decks'),
            ]
            row['reads'] = {}
            for label, rpc, params, field in checks:
                status, data = request('/rest/v1/rpc/' + rpc, params, token)
                row['reads'][label] = status == 200 and isinstance(data, dict) and isinstance(data.get(field), list)
            row['status'] = 'passed' if all(row['reads'].values()) else 'read_failed'
    RESULTS.append(row)
    print(json.dumps(row), flush=True)

summary = os.environ.get('GITHUB_STEP_SUMMARY')
if summary:
    with open(summary, 'a') as file:
        file.write('## Contas QA existentes — login e consultas\n\n')
        for row in RESULTS:
            file.write('- ' + row['role'] + ': ' + row['status'] + '\n')
        file.write('\nNenhuma conta, deck, resgate, denúncia ou sala foi criada.\n')
raise SystemExit(0 if all(row['status'] == 'passed' for row in RESULTS) else 1)
