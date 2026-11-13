from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from uuid import uuid4
from threading import Barrier
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select, text
from sqlalchemy.exc import DatabaseError
from backend.app import models as m
from backend.app.domain import RuleError, dose_state, quantity, schedule

def lot(client,med,qty='30',expiry=None,key=None):
    return client.post(f"/v1/medications/{med['id']}/lots",json={'lot_code':'QA-ONLY','expiry_date':str(expiry or date.today()+timedelta(days=100)),'quantity':qty,'unit':med['unit']},headers={'Idempotency-Key':key or str(uuid4())})

def plan(client,med,qty='1',clock=None):
    instant=datetime.now(UTC)-timedelta(minutes=5)
    data={'dose_quantity':qty,'unit':med['unit'],'times':[clock or instant.strftime('%H:%M')],'weekdays':list(range(7)),'timezone':'UTC','start_date':str(instant.date()),'source_kind':'orientacao_informada','instructions_confirmed':True}
    response=client.post(f"/v1/medications/{med['id']}/plans",json=data,headers={'Idempotency-Key':str(uuid4())})
    assert response.status_code==201,response.text
    return response.json(),instant.date(),data

def occurrence(client,user,day):
    response=client.get(f"/v1/persons/{user['person_id']}/dose-occurrences",params={'start':str(day),'end':str(day)})
    assert response.status_code==200,response.text
    return response.json()['items'][0]

def action(occ,kind='tomada_confirmada',lot_id=None):
    result={'action':kind,'version':occ['revision'],'client_event_id':str(uuid4()),'occurred_at':datetime.now(UTC).isoformat(),'confirmed':True}
    if lot_id: result['lot_id']=lot_id
    if kind=='adiada': result['snooze_minutes']=15
    return result

def test_registration_sessions_and_generic_recovery(client,user):
    assert client.get('/v1/auth/me').json()['email']=='titular@synthetic.invalid'
    unknown=client.post('/v1/auth/recover',json={'email':'missing@synthetic.invalid'}).json()
    known=client.post('/v1/auth/recover',json={'email':'titular@synthetic.invalid'}).json()
    assert known==unknown
    token=client.post('/v1/auth/refresh').json()['access_token']
    assert client.get('/v1/auth/me').status_code==401
    client.headers['Authorization']='Bearer '+token
    assert client.post('/v1/auth/logout').json()['revoked']
    assert client.get('/v1/auth/me').status_code==401
    response=client.post('/v1/auth/session',json={'email':'titular@synthetic.invalid','password':'Synthetic-password-2026'})
    assert response.status_code==200

def test_private_routes_require_authentication(client,app):
    schema=app.openapi()
    for path,operations in schema['paths'].items():
        if not path.startswith('/v1/') or path in ('/v1/auth/register','/v1/auth/session','/v1/auth/recover'): continue
        for method in operations:
            if method not in ('get','post','patch','delete'): continue
            import re
            url=re.sub(r'\{[^}]+\}',str(uuid4()),path)
            response=client.request(method.upper(),url,json={} if method!='get' else None)
            assert response.status_code==401,(method,url,response.status_code,response.text)

def test_validation_redacts_password(client):
    secret='secret-short'
    response=client.post('/v1/auth/register',json={'email':'invalid','password':secret,'privacy_acknowledged':False})
    assert response.status_code==422
    assert secret not in response.text
    assert response.headers['content-type'].startswith('application/problem+json')

def test_medication_and_lot_units_idempotency_and_ledger(client,user,med,app):
    response=lot(client,med,key='same-lot-0001')
    assert response.status_code==201,response.text
    lot_id=response.json()['lot']['id']
    assert response.json()['balance']==30
    replay=lot(client,med,key='same-lot-0001')
    assert replay.json()==response.json()
    assert lot(client,med,qty='29',key='same-lot-0001').status_code==409
    wrong=client.post(f"/v1/medications/{med['id']}/lots",json={'lot_code':'QA','expiry_date':str(date.today()),'quantity':'2','unit':'mL'},headers={'Idempotency-Key':str(uuid4())})
    assert wrong.status_code==422
    movement=client.post(f'/v1/stock-batches/{lot_id}/movements',json={'quantity':'0.5','unit':'comprimido','reason':'saida_manual','confirmed':True},headers={'Idempotency-Key':str(uuid4())})
    assert movement.json()['balance']==29.5
    with app.state.sessions() as db:
        with pytest.raises(DatabaseError):
            db.execute(text('UPDATE inventory_movements SET delta=999'))
        db.rollback()
    reverse=client.post(f"/v1/movements/{movement.json()['movement']['id']}/reversal",json={'confirmed':True},headers={'Idempotency-Key':str(uuid4())})
    assert reverse.json()['balance']==30
    negative=client.post(f'/v1/stock-batches/{lot_id}/movements',json={'quantity':'31','unit':'comprimido','reason':'descarte','confirmed':True},headers={'Idempotency-Key':str(uuid4())})
    assert negative.status_code==422
    assert client.get(f"/v1/persons/{user['person_id']}/inventory/history").status_code==200

@pytest.mark.parametrize('available,expected', [('30','posted'),('0.5','pending_reconciliation')])
def test_confirm_once_no_negative_stock(client,user,med,app,available,expected):
    stock=lot(client,med,available).json()['lot']
    _,day,_=plan(client,med)
    occ=occurrence(client,user,day)
    data=action(occ,lot_id=stock['id'])
    key=str(uuid4())
    first=client.post(f"/v1/dose-occurrences/{occ['id']}/actions",json=data,headers={'Idempotency-Key':key})
    assert first.status_code==200,first.text
    assert first.json()['inventory_effect']==expected
    for _ in range(3):
        assert client.post(f"/v1/dose-occurrences/{occ['id']}/actions",json=data,headers={'Idempotency-Key':key}).json()==first.json()
    with app.state.sessions() as db:
        events=db.scalars(select(m.DoseEvent)).all()
        consumes=db.scalars(select(m.Movement).where(m.Movement.reason=='consumo_confirmado')).all()
        assert len(events)==1
        assert len(consumes)==(1 if expected=='posted' else 0)
    balance=Decimal(str(client.get(f"/v1/medications/{med['id']}/lots").json()['items'][0]['balance']))
    assert balance==Decimal(available)-(Decimal(1) if expected=='posted' else Decimal(0))
    assert client.post(f"/v1/dose-occurrences/{occ['id']}/actions",json=data,headers={'Idempotency-Key':str(uuid4())}).status_code==409

def test_unconfirmed_skipped_snoozed_and_correction(client,user,med):
    stock=lot(client,med).json()['lot']
    _,day,_=plan(client,med)
    occ=occurrence(client,user,day)
    snooze=client.post(f"/v1/dose-occurrences/{occ['id']}/actions",json=action(occ,'adiada'),headers={'Idempotency-Key':str(uuid4())})
    assert snooze.json()['status']=='adiada'
    assert snooze.json()['remind_at']
    occ=occurrence(client,user,day)
    skipped=client.post(f"/v1/dose-occurrences/{occ['id']}/actions",json=action(occ,'nao_tomada_declarada'),headers={'Idempotency-Key':str(uuid4())})
    assert skipped.json()['inventory_effect']=='not_applicable'
    occ=occurrence(client,user,day)
    correction={**action(occ,lot_id=stock['id']),'corrects_event_id':skipped.json()['event_id']}
    taken=client.post(f"/v1/dose-occurrences/{occ['id']}/corrections",json=correction,headers={'Idempotency-Key':str(uuid4())})
    assert taken.status_code==200,taken.text
    occ=occurrence(client,user,day)
    undo={**action(occ,'nao_tomada_declarada'),'corrects_event_id':taken.json()['event_id']}
    assert client.post(f"/v1/dose-occurrences/{occ['id']}/corrections",json=undo,headers={'Idempotency-Key':str(uuid4())}).status_code==200
    assert client.get(f"/v1/medications/{med['id']}/lots").json()['items'][0]['balance']==30
    assert dose_state('programada',datetime.now(UTC)-timedelta(hours=3),datetime.now(UTC),120)=='sem_confirmacao'

def test_lot_selection_required_and_expired(client,user,med):
    stock=lot(client,med,expiry=date.today()-timedelta(days=1)).json()['lot']
    _,day,_=plan(client,med)
    occ=occurrence(client,user,day)
    assert client.post(f"/v1/dose-occurrences/{occ['id']}/actions",json=action(occ,lot_id=stock['id']),headers={'Idempotency-Key':str(uuid4())}).status_code==422
    result=client.post(f"/v1/dose-occurrences/{occ['id']}/actions",json=action(occ),headers={'Idempotency-Key':str(uuid4())})
    assert result.json()['stock_reconciliation_required']
    assert client.get(f"/v1/medications/{med['id']}/lots").json()['items'][0]['balance']==30

def test_concurrent_devices_deduct_once(client,user,med,app):
    stock=lot(client,med).json()['lot']
    _,day,_=plan(client,med)
    occ=occurrence(client,user,day)
    auth=client.headers['Authorization']
    def send(_):
        with TestClient(app) as device:
            return device.post(f"/v1/dose-occurrences/{occ['id']}/actions",json=action(occ,lot_id=stock['id']),headers={'Authorization':auth,'Idempotency-Key':str(uuid4())}).status_code
    with ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(send,range(2)))
    assert sorted(results)==[200,409]
    assert client.get(f"/v1/medications/{med['id']}/lots").json()['items'][0]['balance']==29


@pytest.mark.parametrize('same_occurrence',[True,False])
def test_independent_actors_compete_for_last_unit(client,user,med,app,same_occurrence):
    stock=lot(client,med,'1').json()['lot']
    _,day,_=plan(client,med)
    first=occurrence(client,user,day)
    if same_occurrence:
        doses=[first,first]
    else:
        # Separate user-entered plans create separate aggregates using one physical lot.
        plan(client,med)
        doses=client.get(f"/v1/persons/{user['person_id']}/dose-occurrences",params={'start':str(day),'end':str(day)}).json()['items']
        assert len(doses)==2
    with TestClient(app) as caregiver:
        registered=caregiver.post('/v1/auth/register',json={'email':'race-care@synthetic.invalid','password':'Synthetic-password-2026','privacy_acknowledged':True})
        assert registered.status_code==201,registered.text
        caregiver_token='Bearer '+registered.json()['access_token']
        granted=client.post(f"/v1/persons/{user['person_id']}/permissions",json={'account_email':'race-care@synthetic.invalid','scopes':['view_medications','record_doses']})
        assert granted.status_code==200,granted.text
        actors=[client.headers['Authorization'],caregiver_token]
        gate=Barrier(2)
        def send(index):
            with TestClient(app) as device:
                gate.wait(timeout=10)
                return device.post(f"/v1/dose-occurrences/{doses[index]['id']}/actions",json=action(doses[index],lot_id=stock['id']),headers={'Authorization':actors[index],'Idempotency-Key':str(uuid4())})
        with ThreadPoolExecutor(max_workers=2) as pool:responses=list(pool.map(send,range(2)))
    assert sorted(r.status_code for r in responses)==([200,409] if same_occurrence else [200,200]),[r.text for r in responses]
    if not same_occurrence:
        assert sorted(r.json()['inventory_effect'] for r in responses)==['pending_reconciliation','posted']
    assert client.get(f"/v1/medications/{med['id']}/lots").json()['items'][0]['balance']==0
    with app.state.sessions() as db:
        consumes=db.scalars(select(m.Movement).where(m.Movement.reason=='consumo_confirmado')).all()
        assert len(consumes)==1

def test_permissions_revocation_and_no_cross_family_leak(client,user,med,app):
    other=TestClient(app)
    response=other.post('/v1/auth/register',json={'email':'cuidador@synthetic.invalid','password':'Synthetic-password-2026','privacy_acknowledged':True}).json()
    other.headers['Authorization']='Bearer '+response['access_token']
    assert other.get(f"/v1/medications/{med['id']}").status_code==404
    grant=client.post(f"/v1/persons/{user['person_id']}/permissions",json={'account_email':'cuidador@synthetic.invalid','scopes':['view_medications','record_doses']})
    assert grant.status_code==200,grant.text
    assert other.get(f"/v1/medications/{med['id']}").status_code==200
    assert lot(other,med).status_code==404
    assert client.delete(f"/v1/persons/{user['person_id']}/permissions/{grant.json()['id']}").status_code==200
    assert other.get(f"/v1/medications/{med['id']}").status_code==404
    assert other.get('/v1/privacy/export').json()['medications']==[]

def test_offline_batch_replay_and_revocation(client,user,med,app):
    stock=lot(client,med).json()['lot']
    _,day,_=plan(client,med)
    occ=occurrence(client,user,day)
    key=str(uuid4())
    batch={'commands':[{'occurrence_id':occ['id'],'idempotency_key':key,'payload':action(occ,lot_id=stock['id'])}]}
    first=client.post('/v1/sync/commands',json=batch)
    assert first.json()['items'][0]['status']=='confirmed',first.text
    assert client.post('/v1/sync/commands',json=batch).json()==first.json()
    assert client.get(f"/v1/medications/{med['id']}/lots").json()['items'][0]['balance']==29

def test_replenishment_projection_is_read_only_and_expiry(client,user,med):
    lot(client,med,'5')
    lot(client,med,'2',expiry=date.today()-timedelta(days=1))
    plan(client,med,clock='23:59')
    first=client.get(f"/v1/persons/{user['person_id']}/replenishment")
    assert first.status_code==200,first.text
    projection=first.json()['items'][0]
    assert projection['physical_balance']==7 and projection['eligible_balance']==5 and projection['expired_balance']==2
    assert projection['planned_demand']>5
    assert projection['depletion_date']
    assert client.get(f"/v1/persons/{user['person_id']}/replenishment").json()==first.json()
    assert client.get(f"/v1/persons/{user['person_id']}/alerts").status_code==200
    assert sum(x['balance'] for x in client.get(f"/v1/medications/{med['id']}/lots").json()['items'])==7

def test_shopping_receipt_is_explicit_and_once(client,user,med):
    data={'medication_id':med['id'],'quantity':'30','unit':'comprimido'}
    item=client.post('/v1/shopping-items',json=data,headers={'Idempotency-Key':str(uuid4())}).json()['item']
    assert client.get(f"/v1/medications/{med['id']}/lots").json()['items']==[]
    assert client.post('/v1/shopping-items',json=data,headers={'Idempotency-Key':str(uuid4())}).status_code==409
    key=str(uuid4())
    received={'lot_code':'QA-RECEIVED','expiry_date':str(date.today()+timedelta(days=60)),'quantity':'28','unit':'comprimido','version':1,'received_confirmed':True}
    response=client.post(f"/v1/shopping-items/{item['id']}/receive",json=received,headers={'Idempotency-Key':key})
    assert response.status_code==200,response.text
    assert client.post(f"/v1/shopping-items/{item['id']}/receive",json=received,headers={'Idempotency-Key':key}).json()==response.json()
    assert client.get(f"/v1/medications/{med['id']}/lots").json()['items'][0]['balance']==28

def test_no_fake_prices_and_privacy_export(client,user,med):
    response=client.get('/v1/offers',params={'presentation_id':med['id'],'postal_code':'01001000'})
    assert response.status_code==200 and response.json()['items']==[]
    assert response.json()['independent_sources']==0
    exported=client.get('/v1/privacy/export')
    assert exported.status_code==200
    assert 'password' not in exported.text and 'access_token' not in exported.text
    assert len(exported.json()['medications'])==1
    deletion=client.post('/v1/privacy/deletion-requests',json={'confirmed':True})
    assert deletion.status_code==202 and deletion.json()['status']=='pending_review'

def test_plan_version_preserves_past(client,user,med):
    first,day,data=plan(client,med)
    occ=occurrence(client,user,day)
    data={**data,'times':['23:58'],'version':1}
    edited=client.patch(f"/v1/plans/{first['plan']['id']}",json=data,headers={'Idempotency-Key':str(uuid4())})
    assert edited.status_code==200,edited.text
    assert edited.json()['version']==2
    assert client.get(f"/v1/dose-occurrences/{occ['id']}").json()['version_id']==occ['version_id']

def test_dst_decimal_and_calendar_rules():
    assert quantity('0.125')==Decimal('.125')
    for invalid in ('NaN','Infinity','0.0001','100000001'):
        with pytest.raises(RuleError): quantity(invalid)
    with pytest.raises(RuleError): list(schedule('test',date(2026,3,8),date(2026,3,8),['02:30'],'America/New_York',list(range(7))))
    a=list(schedule('v1',date(2026,11,1),date(2026,11,1),['01:30'],'America/New_York',list(range(7))))
    assert len(a)==1 and a[0]['scheduled_at'].hour==5
    assert a==list(schedule('v1',date(2026,11,1),date(2026,11,1),['01:30'],'America/New_York',list(range(7))))
