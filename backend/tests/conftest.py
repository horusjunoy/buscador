import os
import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient
sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from backend.app.main import create_app
from backend.app.models import Base
from backend.app.database import make_engine
from sqlalchemy.engine import make_url
from sqlalchemy import text
from uuid import uuid4

PG_TEST_DATABASES=[]

@pytest.fixture
def app(tmp_path):
    admin_url=os.getenv('BUSCADOR_TEST_POSTGRES_URL')
    if not admin_url:
        application=create_app(f'sqlite:///{tmp_path}/test.db')
        yield application
        application.state.engine.dispose()
        return
    parsed=make_url(admin_url)
    if parsed.drivername!='postgresql+pg8000' or parsed.host!='127.0.0.1' or parsed.database!='buscador':
        raise RuntimeError('PostgreSQL test URL must target the isolated local Buscador instance.')
    name='buscador_test_'+uuid4().hex[:16]
    admin=make_engine(admin_url).execution_options(isolation_level='AUTOCOMMIT')
    application=None
    with admin.connect() as connection:connection.execute(text(f'CREATE DATABASE "{name}"'))
    PG_TEST_DATABASES.append(name)
    try:
        application=create_app(parsed.set(database=name).render_as_string(hide_password=False))
        yield application
    finally:
        if application:application.state.engine.dispose()
        # A fresh DBAPI connection avoids driver pre-ping changing autocommit.
        admin.dispose()
        with admin.connect() as connection:connection.execute(text(f'DROP DATABASE "{name}" WITH (FORCE)'))
        admin.dispose()

def pytest_sessionfinish(session,exitstatus):
    path=os.getenv('BUSCADOR_PG_COUNTER')
    if path:
        import json
        Path(path).write_text(json.dumps({'isolated_application_databases_exercised':len(PG_TEST_DATABASES),'pytest_exit_code':int(exitstatus)},indent=2)+'\n')

@pytest.fixture
def client(app):
    with TestClient(app) as c: yield c

@pytest.fixture
def user(client):
    response=client.post('/v1/auth/register',json={'email':'titular@synthetic.invalid','password':'Synthetic-password-2026','privacy_acknowledged':True})
    assert response.status_code==201,response.text
    body=response.json()
    client.headers['Authorization']='Bearer '+body['access_token']
    person=client.post(f"/v1/households/{body['household_id']}/persons",json={'display_name':'Pessoa sintética QA','timezone':'UTC'},headers={'Idempotency-Key':'profile-synthetic-0001'})
    assert person.status_code==201,person.text
    return {**body,'person_id':person.json()['id']}

@pytest.fixture
def med(client,user):
    data={'name':'Medicamento sintético QA','ingredient':'Substância sintética','strength':'1 unidade de teste','form':'comprimido','unit':'comprimido','pack_quantity':'30','presentation_confirmed':True}
    response=client.post(f"/v1/persons/{user['person_id']}/medications",json=data,headers={'Idempotency-Key':'medication-0001'})
    assert response.status_code==201,response.text
    return response.json()['medication']
