#!/usr/bin/env python3
"""QA autorizado: contas existentes, fixture exclusiva, relatórios sem credenciais.
prepare cria/salva um deck privado e envia à revisão; verify testa as denúncias
somente após aprovação administrativa EXCLUSIVA da fixture. Não usa decks reais.
"""
import hashlib
import json
import os
from pathlib import Path
import sys
import time
import urllib.request
import uuid
import community_claim_live as qa
from community_e2e import png

FIXTURE = qa.ROOT / 'evidence/community-claims/live/report-fixture.json'
TAG = 'QSE QA REPORT ' + qa.RUN + '-' + qa.ATTEMPT
qa.REPORT.update({'stage': sys.argv[1], 'fixture_tag': TAG})
qa.REPORT.pop('room_tag', None)


def request(method, path, body=None, role='OWNER', raw=None):
    if raw is None:
        return qa.call(path, body, qa.TOKENS[role], method)
    req = urllib.request.Request(qa.GAME + path, data=raw, method=method,
        headers={'apikey':qa.CFG['publishable_key'],
                 'Authorization':'Bearer ' + qa.TOKENS[role], 'Content-Type':'image/png'})
    try:
        with qa.OPENER.open(req, timeout=40) as response:
            return response.status, None
    except urllib.error.HTTPError as error:
        return error.code, None


def login():
    for role in ['OWNER','READER','R1']:
        email, password = [os.environ.get('QSE_TEST_' + role + '_' + key) for key in ['EMAIL','PASSWORD']]
        qa.check(bool(email and password), 'existing_credentials_' + role)
        status, data = qa.call('/auth/v1/token?grant_type=password', {'email':email,'password':password})
        qa.check(status == 200 and isinstance(data,dict) and bool(data.get('access_token')), 'login_' + role)
        qa.TOKENS[role], qa.USERS[role] = data['access_token'],data['user']['id']
    qa.check(len(set(qa.USERS.values())) == 3, 'three_distinct_qa_accounts')


def prepare():
    deck, cards = str(uuid.uuid4()), [str(uuid.uuid4()) for _ in range(5)]
    owner = qa.USERS['OWNER']
    fixture = {'deck_id':deck,'cards':cards,'tag':TAG,
               'owner_marker':hashlib.sha256((TAG+owner).encode()).hexdigest()}
    FIXTURE.write_text(json.dumps(fixture,indent=2)+'\n')
    qa.REPORT['fixture_deck_id'] = deck
    status,_ = request('POST','/rest/v1/qse_creator_decks',[
        {'id':deck,'owner_id':owner,'name':TAG,'category':'Outros',
         'description':'Fixture QA temporária. Será removida após os testes.', 'requested_visibility':'public'}])
    qa.check(status in (200,201,204), 'author_creates_private_deck')
    rows=[]
    for i,card in enumerate(cards):
        prefix=owner+'/'+deck+'/'+card
        for suffix,size in [('original',(120,168)),('library',(100,140)),('duel',(160,50))]:
            status,_=request('POST','/storage/v1/object/qse-deck-originals/'+prefix+'_'+suffix+'.png',raw=png(*size,[40+i*35,90,160]))
            qa.check(status in (200,201),'author_upload_card_'+str(i+1)+'_'+suffix)
        rows.append({'id':card,'deck_id':deck,'position':i,'name':'QA Carta '+str(i+1),
                     'description':'Fixture de teste','image_original_path':prefix+'_original.png'})
    status,_=request('POST','/rest/v1/qse_creator_cards',rows)
    qa.check(status in (200,201,204),'author_saves_five_named_cards')
    status,data=request('GET','/rest/v1/qse_creator_cards?select=id,name&deck_id=eq.'+deck)
    qa.check(status==200 and isinstance(data,list) and len(data)==5 and {r['name'] for r in data}=={r['name'] for r in rows},'saved_cards_read_back_from_account')
    status,data=request('GET','/rest/v1/qse_creator_cards?select=id&deck_id=eq.'+deck,role='READER')
    qa.check(status==200 and data==[],'other_account_cannot_read_private_draft')
    data=qa.rpc('OWNER','qse_deck_publish_request',{'p_deck':deck})
    qa.check(data.get('status')=='pending_review','author_submits_saved_deck_to_review')
    qa.REPORT['fixture_tag']=TAG


def expect_error(role,name,params,code,label):
    status,data=qa.call('/rest/v1/rpc/'+name,params,qa.TOKENS[role])
    qa.check(status==200 and isinstance(data,dict) and data.get('error')==code,label)


def verify():
    fixture=json.loads(FIXTURE.read_text());deck=fixture['deck_id'];tag=fixture['tag']
    qa.REPORT.update({'fixture_deck_id':deck,'fixture_tag':tag})
    qa.check(hashlib.sha256((tag+qa.USERS['OWNER']).encode()).hexdigest()==fixture['owner_marker'],'fixture_belongs_to_qa_author')
    data=qa.rpc('READER','qse_community_deck',{'p_deck':deck})
    qa.check(len(data.get('cards',[]))==5,'approved_fixture_has_five_cards')
    creator=data.get('deck',{}).get('creator',{})
    qa.check(bool(creator.get('nickname')) and bool(creator.get('public_id')) and 'owner_id' not in creator,'community_credits_public_creator')
    for role,total in [('READER',1),('R1',2)]:
        result=qa.rpc(role,'qse_deck_report',{'p_deck':deck,'p_reason':tag})
        qa.check(result.get('reported') is True and result.get('report_count')==total,'deck_report_persisted_'+role)
    expect_error('READER','qse_deck_report',{'p_deck':deck,'p_reason':tag},'already_reported','duplicate_deck_report_refused')
    expect_error('OWNER','qse_deck_report',{'p_deck':deck,'p_reason':tag},'cannot_report_own','own_deck_report_refused')
    expect_error('OWNER','qse_deck_report',{'p_deck':deck,'p_reason':''},'invalid_reason','empty_deck_report_refused')
    profiles={role:qa.rpc(role,'qse_profile_self') for role in ['OWNER','READER']}
    target=profiles['READER']['public_id']
    for name,params in [('qse_deck_report',{'p_deck':deck,'p_reason':tag}),('qse_player_report',{'p_public_id':target,'p_reason':tag})]:
        status,_=qa.call('/rest/v1/rpc/'+name,params)
        qa.check(status in (401,403),'anonymous_'+name+'_refused')
    result=qa.rpc('OWNER','qse_player_report',{'p_public_id':target,'p_reason':tag})
    qa.check(result.get('reported') is True and set(result)=={'reported'},'player_report_confirmed_without_private_ids')
    expect_error('OWNER','qse_player_report',{'p_public_id':target,'p_reason':tag},'already_reported','duplicate_player_report_refused')
    expect_error('OWNER','qse_player_report',{'p_public_id':profiles['OWNER']['public_id'],'p_reason':tag},'cannot_report_self','self_player_report_refused')
    expect_error('OWNER','qse_player_report',{'p_public_id':target,'p_reason':' x '},'invalid_reason','short_player_reason_refused')
    expect_error('OWNER','qse_player_report',{'p_public_id':'QSE-NOT-REAL','p_reason':tag},'player_not_found','missing_player_refused')
    status,data=request('GET','/rest/v1/qse_deck_reports?select=reason&deck_id=eq.'+deck,role='R1')
    qa.check(status in (401,403),'reporter_cannot_read_private_reports')
    qa.rpc('OWNER','qse_deck_unpublish',{'p_deck':deck})
    prefixes=[]
    for card in fixture['cards']:
        for suffix in ['original','library','duel']:
            prefixes.append(qa.USERS['OWNER']+'/'+deck+'/'+card+'_'+suffix+'.png')
    status,_=request('DELETE','/storage/v1/object/qse-deck-originals',{'prefixes':prefixes})
    qa.check(status in (200,204),'author_removes_qa_image_objects')
    status,_=request('DELETE','/rest/v1/qse_creator_cards?deck_id=eq.'+deck)
    qa.check(status in (200,204),'author_removes_qa_cards')
    status,_=request('DELETE','/rest/v1/qse_creator_decks?id=eq.'+deck)
    qa.check(status in (200,204),'author_removes_qa_deck')
    status,data=request('GET','/rest/v1/qse_creator_decks?select=id&id=eq.'+deck)
    qa.check(status==200 and data==[],'qa_deck_removal_read_back')
    qa.REPORT['player_report_cleanup']='pending_scoped_admin_verification'


def main():
    qa.OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    try:
        login()
        if sys.argv[1]=='prepare': prepare()
        elif sys.argv[1]=='verify': verify()
        else: raise qa.Failure('invalid_stage')
        qa.REPORT['status']='passed'
    except Exception as error:
        qa.REPORT['status']='failed'
        qa.REPORT['failure']=str(error) if isinstance(error,qa.Failure) else type(error).__name__
    finally:
        qa.REPORT['sessions_logged_out']={}
        for role,token in qa.TOKENS.items():
            status,_=qa.call('/auth/v1/logout?scope=local',token=token)
            qa.REPORT['sessions_logged_out'][role]=status in (200,204)
        qa.REPORT['passed']=sum(c['passed'] for c in qa.REPORT['checks'])
        qa.REPORT['total']=len(qa.REPORT['checks'])
        qa.OUTPUT.write_text(json.dumps(qa.REPORT,indent=2)+'\n')
        print('QA_RESULT '+json.dumps({k:qa.REPORT[k] for k in ['status','passed','total']}),flush=True)
    return 0 if qa.REPORT['status']=='passed' else 1


if __name__=='__main__': raise SystemExit(main())
