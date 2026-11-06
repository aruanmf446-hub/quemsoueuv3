#!/usr/bin/env python3
"""Authorized production QA with existing OWNER/READER/R1 accounts.
No account creation/deletion, nickname changes, moderation or reports.
Claims remain on OWNER as normal QA inventory. Only newly created private
rooms/matches require scoped database cleanup after the run.
Credentials and signed URLs stay in memory; the report is sanitized.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import time
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[2]
CFG = json.loads((ROOT / 'data/backend/client.json').read_text())
GAME = 'https://shuzporktifgiotvnpbz.supabase.co'
CATALOG = 'https://bsxicvlngphazesuzaee.supabase.co'
assert CFG['url'].rstrip('/') == GAME
RUN = os.environ['GITHUB_RUN_ID']
ATTEMPT = os.environ.get('GITHUB_RUN_ATTEMPT', '1')
assert RUN.isdigit() and ATTEMPT.isdigit()
TAG = 'QSE QA CLAIM ' + RUN + '-' + ATTEMPT
assert len(TAG) <= 32
REPORT = {'status':'running','run_id': RUN, 'attempt': ATTEMPT, 'room_tag': TAG,
          'checks': [], 'rooms': [], 'skipped': [], 'accounts_created_or_deleted': False}
OUTPUT = ROOT / 'evidence/community-claims/live' / (RUN + '-' + ATTEMPT + '.json')
TOKENS = {}
USERS = {}


class Failure(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


OPENER = urllib.request.build_opener(NoRedirect)


def call(path, body=None, token=None, method='POST', raw=False, timeout=35):
    url = path if path.startswith('https://') else GAME + path
    if url.startswith(GAME + '/'):
        headers = {'apikey': CFG['publishable_key']}
        if token:
            headers['Authorization'] = 'Bearer ' + token
    else:
        assert token is None and url.startswith(CATALOG + '/storage/v1/object/')
        headers = {'apikey': CFG['connections']['catalog']['publishable_key']}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, method=method, data=data, headers=headers)
    try:
        with OPENER.open(req, timeout=timeout) as response:
            payload = response.read(4194305)
            if raw:
                return response.status, payload
            return response.status, json.loads(payload) if payload else None
    except urllib.error.HTTPError as error:
        try:
            value = json.loads(error.read(8192))
        except (ValueError, UnicodeError):
            value = None
        return error.code, value
    except (urllib.error.URLError, TimeoutError):
        return 0, None


def check(ok, name):
    REPORT['checks'].append({'name': name, 'passed': bool(ok)})
    OUTPUT.write_text(json.dumps(REPORT, indent=2) + '\n')
    print(('PASS ' if ok else 'FAIL ') + name, flush=True)
    if not ok:
        raise Failure(name)


def rpc(role, name, params=None):
    status, data = call('/rest/v1/rpc/' + name, params or {}, TOKENS[role])
    if status != 200 or not isinstance(data, dict) or data.get('error'):
        code = data.get('error', data.get('code', '')) if isinstance(data, dict) else ''
        if isinstance(code, str) and re.fullmatch('[a-zA-Z0-9_]{1,48}', code):
            REPORT['last_rpc_error'] = {'rpc': name, 'http_status': status, 'code': code}
        raise Failure('rpc_failed_' + name)
    return data


def edge(role, body):
    status, data = call('/functions/v1/qse-deck-catalog', body, TOKENS[role], timeout=130)
    if isinstance(data, dict) and isinstance(data.get('error'), str):
        code = data['error']
        if re.fullmatch('[a-zA-Z0-9_]{1,48}', code):
            REPORT['gateway_error'] = code
    return status, data


def inventory(role):
    data = rpc(role, 'qse_community_inventory')
    check(isinstance(data.get('items'), list), 'inventory_contract_' + role)
    return data['items']


def signature(items):
    return sorted((d['deck_id'], d['version_id']) for d in items)


def run():
    for role in ['OWNER', 'READER', 'R1']:
        email = os.environ.get('QSE_TEST_' + role + '_EMAIL')
        password = os.environ.get('QSE_TEST_' + role + '_PASSWORD')
        check(bool(email and password), 'existing_credentials_' + role)
        status, data = call('/auth/v1/token?grant_type=password', {'email': email, 'password': password})
        check(status == 200 and isinstance(data, dict) and bool(data.get('access_token')), 'login_' + role)
        TOKENS[role], USERS[role] = data['access_token'], data['user']['id']
    check(len(set(USERS.values())) == 3, 'three_distinct_existing_accounts')
    REPORT['owner_marker'] = hashlib.sha256((TAG + USERS['OWNER']).encode()).hexdigest()
    baseline = {role: inventory(role) for role in TOKENS}
    listing = rpc('OWNER', 'qse_community_decks', {'p_query': None, 'p_theme': None,
                   'p_sort': 'recent', 'p_limit': 48, 'p_cursor': None})
    check(bool(listing.get('items')), 'published_deck_available')
    deck = str(uuid.UUID(listing['items'][0]['id']))
    REPORT['source_deck_id'] = deck
    for role in ['OWNER', 'READER']:
        profile = rpc(role, 'qse_profile_self')
        nickname = profile.get('nickname')
        check(isinstance(nickname, str) and 3 <= len(nickname.strip()) <= 24,
              'existing_nickname_' + role)
    status, claim = edge('OWNER', {'action': 'claim', 'deck_id': deck})
    check(status == 200 and isinstance(claim, dict) and claim.get('claimed') is True, 'gateway_claim_confirmed')
    ref = claim['deck_ref']
    check(bool(re.fullmatch('community_[0-9a-f]{32}', ref)), 'stable_version_reference')
    REPORT['deck_ref'] = ref
    status, repeated = edge('OWNER', {'action': 'claim', 'deck_id': deck})
    check(status == 200 and repeated.get('already_owned') is True and repeated.get('deck_ref') == ref,
          'repeated_claim_idempotent')
    owned = inventory('OWNER')
    check(sum(d['deck_id'] == deck for d in owned) == 1, 'exactly_one_owner_entitlement')
    for role in ['READER', 'R1']:
        check(signature(inventory(role)) == signature(baseline[role]), 'unchanged_collection_' + role)
    unowned = next((r for r in ['READER', 'R1'] if not any(d['id'] == ref for d in baseline[r])), None)
    if unowned:
        status, denied = call('/rest/v1/rpc/qse_community_manifests', {'p_refs': [ref]}, TOKENS[unowned])
        check(status == 200 and denied.get('error') == 'deck_not_owned', 'nonmember_manifest_refused')
        catalog = rpc(unowned, 'qse_duel_decks')
        check(not any(d['id'] == ref for d in catalog['decks']), 'unowned_deck_hidden_from_selector')
        status, denied = call('/rest/v1/rpc/qse_duel_create', {'p_name': TAG, 'p_public': False,
                              'p_settings': {'deck_ids': [ref]}}, TOKENS[unowned])
        check(status == 200 and denied.get('error') == 'invalid_settings', 'unowned_room_settings_refused')
    else:
        REPORT['skipped'].append('unowned_guards_all_QA_accounts_already_own_version')
    status, manifest = edge('OWNER', {'action': 'manifests', 'deck_refs': [ref]})
    check(status == 200 and isinstance(manifest.get('items'), list) and len(manifest['items']) == 1,
          'authorized_catalog_manifest')
    item = manifest['items'][0]
    cards = item['cards']
    check(5 <= len(cards) <= 30 and bool(item.get('creator')), 'approved_cards_and_creator_preserved')
    for kind in ['library', 'duel']:
        url = cards[0][kind + '_url']
        check(url.startswith(CATALOG + '/storage/v1/object/sign/qse-community-previews/'), 'signed_catalog_url_' + kind)
        status, data = call(url, method='GET', raw=True)
        check(status == 200 and data.startswith(b'\x89PNG\r\n\x1a\n') and len(data) <= 4194304,
              'real_private_png_download_' + kind)
    status, _ = call(CATALOG + '/storage/v1/object/authenticated/qse-community-previews/' + cards[0]['duel_path'],
                     method='GET', raw=True)
    check(status in (400, 401, 403, 404), 'unsigned_private_preview_refused')
    catalog = rpc('OWNER', 'qse_duel_decks')
    check(any(d['id'] == ref for d in catalog['decks']), 'claimed_deck_in_online_selector')
    room = rpc('OWNER', 'qse_duel_create', {'p_name': TAG, 'p_public': False,
                 'p_settings': {'deck_ids': [ref], 'max_players': 4, 'cards_per_player': 3}})
    rid = str(uuid.UUID(room['room']['id']))
    REPORT['rooms'].append({'id': rid})
    check(room['room']['is_public'] is False, 'private_test_room_created')
    joined = rpc('READER', 'qse_duel_join', {'p_code': room['room']['code']})
    check(joined['room']['id'] == rid, 'second_QA_player_joins')
    member_a, member_b = room['you']['member_id'], joined['you']['member_id']
    status, shared = edge('READER', {'action': 'manifests', 'deck_refs': [ref]})
    check(status == 200 and len(shared.get('items', [])) == 1, 'opponent_authorized_manifest')
    check(signature(inventory('READER')) == signature(baseline['READER']), 'room_access_does_not_gift_deck')
    bot = rpc('OWNER', 'qse_duel_add_bot', {'p_room': rid})
    check(any(m['is_bot'] for m in bot['members']), 'bot_in_online_room')
    started = rpc('OWNER', 'qse_duel_start', {'p_room': rid})
    mid = str(uuid.UUID(started['match']['id']))
    REPORT['rooms'][0]['match_id'] = mid
    check(started['room']['status'] == 'in_match', 'real_community_match_started')
    pool = [c['card_id'] for c in started['match']['pool']]
    check(len(pool) == len(cards) and all(c.startswith(ref + '/') for c in pool), 'match_uses_immutable_community_cards')
    selected = rpc('OWNER', 'qse_duel_select', {'p_room': rid, 'p_cards': pool[:3]})
    check(len(selected['match']['my_cards']) == 3, 'owner_selects_three_cards')
    selected = rpc('READER', 'qse_duel_select', {'p_room': rid, 'p_cards': pool[-3:]})
    check(len(selected['match']['my_cards']) == 3, 'opponent_selects_three_cards')
    turn_order = selected['match']['turn_order']
    picked = False
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        rpc('READER', 'qse_duel_heartbeat', {'p_room': rid})
        state = rpc('OWNER', 'qse_duel_room', {'p_room': rid})
        match = state['match']
        if any((e.get('card_id') or '').startswith(ref + '/') and e.get('revealed') for e in match['events']):
            check(match['turn_order'] == turn_order, 'turn_order_preserved_through_reveal')
            check(True, 'community_card_reveal_over_real_HTTP')
            break
        if match['phase'] == 'turns' and not picked:
            actor = {'OWNER': member_a, 'READER': member_b}
            for role, member in actor.items():
                if match['turn_member'] == member:
                    choice = next(c['card_id'] for c in match['pool'] if not c['removed'])
                    rpc(role, 'qse_duel_pick', {'p_room': rid, 'p_card': choice})
                    picked = True
                    break
        time.sleep(1)
    else:
        check(False, 'community_card_reveal_over_real_HTTP')
    rpc('READER', 'qse_duel_leave', {'p_room': rid})
    if unowned == 'READER':
        status, denied = call('/rest/v1/rpc/qse_community_manifests', {'p_refs': [ref]}, TOKENS['READER'])
        check(status == 200 and denied.get('error') == 'deck_not_owned', 'leaving_revokes_future_manifest_access')
    rpc('OWNER', 'qse_duel_leave', {'p_room': rid})
    check(signature(inventory('READER')) == signature(baseline['READER']), 'opponent_collection_preserved_after_match')
    check(signature(inventory('R1')) == signature(baseline['R1']), 'third_QA_collection_preserved')


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    REPORT['started_at'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    OUTPUT.write_text(json.dumps(REPORT, indent=2) + '\n')
    try:
        run()
        REPORT['status'] = 'checks_passed_cleanup_pending'
    except Exception as error:
        REPORT['status'] = 'failed'
        REPORT['failure'] = str(error) if isinstance(error, Failure) else type(error).__name__
        print('QA_FAILED ' + REPORT['failure'], flush=True)
    finally:
        REPORT['leave_requests'] = []
        for room in REPORT['rooms']:
            for role in ['READER', 'OWNER']:
                if role in TOKENS:
                    status, _ = call('/rest/v1/rpc/qse_duel_leave', {'p_room': room['id']}, TOKENS[role])
                    REPORT['leave_requests'].append({'role': role, 'http_status': status})
        REPORT['sessions_logged_out'] = {}
        for role, token in TOKENS.items():
            status, _ = call('/auth/v1/logout?scope=local', token=token)
            REPORT['sessions_logged_out'][role] = status in (200, 204)
        REPORT['passed'] = sum(c['passed'] for c in REPORT['checks'])
        REPORT['total'] = len(REPORT['checks'])
        OUTPUT.write_text(json.dumps(REPORT, indent=2) + '\n')
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a') as file:
                file.write('## Resgate e partida com contas QA existentes\n\n')
                file.write(str(REPORT['passed']) + '/' + str(REPORT['total']) + ' verificações aprovadas.\n\n')
                file.write('Resultado: ' + REPORT['status'] + '. Limpeza de banco será verificada pelo operador.\n')
        print('QA_RESULT ' + json.dumps({'status': REPORT['status'], 'passed': REPORT['passed'], 'total': REPORT['total']}), flush=True)
    return 0 if REPORT['status'] == 'checks_passed_cleanup_pending' else 1


if __name__ == '__main__':
    raise SystemExit(main())
