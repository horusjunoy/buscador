from datetime import date, timedelta
from uuid import uuid4
from fastapi.testclient import TestClient
from sqlalchemy import event,select,func
from backend.app.domain import RuleError
from backend.app.models import Account
from backend.tests.test_core import lot,plan,occurrence,action

def test_problem_contract_payload_limit_and_header(client,app):
    schema=app.openapi()
    operation=schema['paths']['/v1/auth/me']['get']
    assert operation['security']==[{'bearerAuth':[]}]
    assert 'application/problem+json' in operation['responses']['401']['content']
    denied=client.get('/v1/auth/me')
    assert denied.headers['WWW-Authenticate']=='Bearer'
    huge=client.post('/v1/auth/register',content=b' '*65537,headers={'Content-Type':'application/json'})
    assert huge.status_code==413 and huge.json()['code']=='PAYLOAD_TOO_LARGE'

def test_no_success_response_is_sent_before_transaction_commit(app):
    def reject_commit(session):
        if session.bind is app.state.engine:raise RuleError('COMMIT_UNAVAILABLE','Transação indisponível.',503)
    session_class=app.state.sessions.class_
    event.listen(session_class,'before_commit',reject_commit)
    try:
        with TestClient(app,raise_server_exceptions=False) as client:
            response=client.post('/v1/auth/register',json={'email':'commit-fault@synthetic.invalid','password':'Synthetic-password-2026','privacy_acknowledged':True})
            assert response.status_code==503,response.text
            assert 'access_token' not in response.text
    finally:event.remove(session_class,'before_commit',reject_commit)
    with app.state.sessions() as db:assert db.scalar(select(func.count()).select_from(Account))==0

def test_person_creation_replay(client,user):
    data={'display_name':'Pessoa sintética QA','timezone':'UTC'}
    response=client.post(f"/v1/households/{user['household_id']}/persons",json=data,headers={'Idempotency-Key':'profile-synthetic-0001'})
    assert response.status_code==201 and response.json()['id']==user['person_id']
    assert len(client.get('/v1/persons').json()['items'])==1

def test_cross_family_resource_matrix_and_sync_denial(client,user,med,app):
    stock=lot(client,med).json()['lot']
    treatment,day,data=plan(client,med)
    dose=occurrence(client,user,day)
    item=client.post('/v1/shopping-items',json={'medication_id':med['id'],'quantity':'30','unit':'comprimido'},headers={'Idempotency-Key':str(uuid4())}).json()['item']
    with TestClient(app) as other:
        registration=other.post('/v1/auth/register',json={'email':'outside@synthetic.invalid','password':'Synthetic-password-2026','privacy_acknowledged':True}).json()
        other.headers['Authorization']='Bearer '+registration['access_token']
        for path in (f"/v1/medications/{med['id']}",f"/v1/medications/{med['id']}/lots",f"/v1/dose-occurrences/{dose['id']}",*[f"/v1/persons/{user['person_id']}/{suffix}" for suffix in ('medications','plans','inventory/history','replenishment','alerts','shopping-items','permissions')]):
            response=other.get(path)
            assert response.status_code==404,(path,response.text)
            assert med['name'] not in response.text
        denied=other.post(f"/v1/dose-occurrences/{dose['id']}/actions",json=action(dose,lot_id=stock['id']),headers={'Idempotency-Key':str(uuid4())})
        assert denied.status_code==404
        command={'commands':[{'occurrence_id':dose['id'],'idempotency_key':str(uuid4()),'payload':action(dose,lot_id=stock['id'])}]}
        batch=other.post('/v1/sync/commands',json=command).json()['items'][0]
        assert batch['status']=='rejected' and batch['http_status']==404
        assert other.delete(f"/v1/shopping-items/{item['id']}").status_code==404
        assert other.post(f"/v1/stock-batches/{stock['id']}/movements",json={'quantity':'1','unit':'comprimido','reason':'descarte','confirmed':True},headers={'Idempotency-Key':str(uuid4())}).status_code==404

def test_plan_suspension_advances_state_revision_without_mutating_version(client,user,med):
    first,day,data=plan(client,med)
    response=client.post(f"/v1/plans/{first['plan']['id']}/status",json={'version':1,'status':'suspenso','confirmed':True},headers={'Idempotency-Key':str(uuid4())})
    assert response.status_code==200,response.text
    assert response.json()['version']==2
    listed=client.get(f"/v1/persons/{user['person_id']}/plans").json()['items'][0]
    assert listed['revision']==2 and listed['active_version']['revision']==1
    stale=client.patch(f"/v1/plans/{listed['id']}",json={**data,'version':1},headers={'Idempotency-Key':str(uuid4())})
    assert stale.status_code==409

def test_permission_for_person_a_does_not_reveal_person_b_in_same_family(client,user,med,app):
    second=client.post(f"/v1/households/{user['household_id']}/persons",json={'display_name':'Outra pessoa sintética','timezone':'UTC'},headers={'Idempotency-Key':str(uuid4())}).json()
    with TestClient(app) as caregiver:
        registered=caregiver.post('/v1/auth/register',json={'email':'care-scope@synthetic.invalid','password':'Synthetic-password-2026','privacy_acknowledged':True}).json()
        caregiver.headers['Authorization']='Bearer '+registered['access_token']
        assert client.post(f"/v1/persons/{user['person_id']}/permissions",json={'account_email':'care-scope@synthetic.invalid','scopes':['view_medications']}).status_code==200
        assert [p['id'] for p in caregiver.get('/v1/persons').json()['items']]==[user['person_id']]
        assert caregiver.get(f"/v1/medications/{med['id']}").status_code==200
        assert caregiver.get(f"/v1/persons/{second['id']}/medications").status_code==404
        assert caregiver.post(f"/v1/persons/{user['person_id']}/medications",json={'name':'QA','ingredient':'QA','strength':'1 QA','form':'comprimido','unit':'comprimido','pack_quantity':'1','presentation_confirmed':True},headers={'Idempotency-Key':str(uuid4())}).status_code==404

def test_revocation_denies_already_accepted_replay_and_offline_retry(client,user,med,app):
    _,day,_=plan(client,med)
    dose=occurrence(client,user,day)
    with TestClient(app) as caregiver:
        registered=caregiver.post('/v1/auth/register',json={'email':'revoked-care@synthetic.invalid','password':'Synthetic-password-2026','privacy_acknowledged':True}).json()
        caregiver.headers['Authorization']='Bearer '+registered['access_token']
        permission=client.post(f"/v1/persons/{user['person_id']}/permissions",json={'account_email':'revoked-care@synthetic.invalid','scopes':['view_medications','record_doses']}).json()
        key=str(uuid4());payload=action(dose,'nao_tomada_declarada')
        assert caregiver.post(f"/v1/dose-occurrences/{dose['id']}/actions",json=payload,headers={'Idempotency-Key':key}).status_code==200
        assert client.delete(f"/v1/persons/{user['person_id']}/permissions/{permission['id']}").status_code==200
        assert caregiver.post(f"/v1/dose-occurrences/{dose['id']}/actions",json=payload,headers={'Idempotency-Key':key}).status_code==404
        batch=caregiver.post('/v1/sync/commands',json={'commands':[{'occurrence_id':dose['id'],'idempotency_key':key,'payload':payload}]}).json()
        assert batch['items'][0]['status']=='rejected' and batch['items'][0]['http_status']==404
