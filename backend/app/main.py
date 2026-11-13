"""Local/HML API. External providers and publication remain explicitly gated."""
import os
import secrets
import threading
import time
from collections import defaultdict, deque
from datetime import timedelta, date
from pathlib import Path
from uuid import uuid4
from fastapi import Depends, FastAPI, Header, Query, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.openapi.utils import get_openapi
from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError
from . import models as m, schemas as s, services as svc
from .database import DATABASE_URL, factory, make_engine, migrate
from .domain import RuleError, SCOPES, schedule, timezone, utc
from .security import digest, hash_password, issue_session, verify_password

ROOT = Path(__file__).resolve().parents[2]

def create_app(database_url=DATABASE_URL):
    if os.getenv('APP_ENV','local') not in ('local','test','hml'):
        raise RuntimeError('Production is not authorized/configured for this delivery.')
    if database_url.startswith('sqlite:///'):
        Path(database_url.removeprefix('sqlite:///')).parent.mkdir(parents=True,exist_ok=True)
    engine = make_engine(database_url)
    if os.getenv('AUTO_MIGRATE','1')=='1':migrate(engine)
    sessions = factory(engine)
    app = FastAPI(title='Buscador de Medicamentos', version='0.1.0',docs_url=None,redoc_url=None, description='NÃºcleo local/HML; sem fontes comerciais contratadas. Quantidades sÃ£o decimais e doses exigem declaraÃ§Ã£o explÃ­cita.')
    app.state.engine, app.state.sessions = engine, sessions
    rate = defaultdict(deque)
    rate_lock = threading.Lock()
    dummy_password = hash_password(secrets.token_urlsafe(32))

    def problem(status, code, detail):
        headers={'WWW-Authenticate':'Bearer'} if status==401 else {'Retry-After':'60'} if status==429 else {}
        return JSONResponse(status_code=status,content={'type':f'urn:buscador:problem:{code.lower()}', 'title':code,'status':status,'detail':detail,'code':code},media_type='application/problem+json',headers=headers)

    @app.exception_handler(RuleError)
    async def rule_error(request, exc): return problem(exc.status,exc.code,exc.detail)

    @app.exception_handler(RequestValidationError)
    async def validation_error(request, exc):
        # No echoing input, passwords, clinical fields, or validation contexts.
        fields = ', '.join('.'.join(str(x) for x in e['loc'] if x!='body') for e in exc.errors())
        return problem(422,'VALIDATION_ERROR',f'Revise os campos obrigatÃ³rios e formatos: {fields}.')

    @app.exception_handler(IntegrityError)
    async def integrity_error(request, exc): return problem(409,'STATE_CONFLICT','O registro jÃ¡ existe ou foi modificado. Atualize e confira antes de tentar novamente.')

    @app.middleware('http')
    async def headers(request, call_next):
        if request.url.path.startswith('/v1/') and request.method in ('POST','PATCH','PUT'):
            if len(await request.body())>65536:
                return problem(413,'PAYLOAD_TOO_LARGE','A solicitaÃ§Ã£o excede o limite permitido.')
        response = await call_next(request)
        response.headers['X-Content-Type-Options']='nosniff'
        response.headers['Referrer-Policy']='no-referrer'
        response.headers['X-Frame-Options']='DENY'
        response.headers['X-Request-ID']=str(uuid4())
        if request.url.path.startswith('/v1'):
            response.headers['Cache-Control']='no-store'
        return response

    def db_dependency():
        with sessions() as db:
            if engine.dialect.name=='sqlite': db.execute(text('BEGIN IMMEDIATE'))
            try:
                yield db
                db.commit()
            except Exception:
                db.rollback()
                raise

    DB = Depends(db_dependency,scope='function')

    def actor(request: Request, authorization: str | None = Header(default=None), db=DB):
        if not authorization or not authorization.startswith('Bearer '):
            raise RuleError('UNAUTHENTICATED','Entre na sua conta para continuar.',401)
        auth_session = db.get(m.AuthSession,digest(authorization[7:]))
        if not auth_session or auth_session.revoked or utc(auth_session.expires_at)<=m.now():
            raise RuleError('UNAUTHENTICATED','Sua sessÃ£o terminou. Entre novamente.',401)
        request.state.session_hash=auth_session.token_hash
        return db.get(m.Account,auth_session.account_id)

    ACTOR = Depends(actor)

    def throttle(request):
        key=(request.client.host if request.client else 'local',request.url.path)
        instant=time.monotonic()
        with rate_lock:
            queue=rate[key]
            while queue and queue[0]<instant-60: queue.popleft()
            if len(queue)>=10: raise RuleError('RATE_LIMITED','Muitas tentativas. Aguarde um minuto.',429)
            queue.append(instant)
            if len(rate)>10000:
                for stale in list(rate):
                    if not rate[stale] or rate[stale][-1]<instant-60: del rate[stale]

    def page(query, db, limit, cursor):
        if cursor: query=query.where(query.column_descriptions[0]['entity'].id>cursor)
        model=query.column_descriptions[0]['entity']
        items=db.scalars(query.order_by(model.id).limit(limit+1)).all()
        return {'items':[svc.row(x) for x in items[:limit]], 'next_cursor':items[limit-1].id if len(items)>limit else None}

    @app.get('/health',tags=['operation'])
    def health(db=DB):
        db.execute(text('SELECT 1'))
        return {'status':'ok','environment':os.getenv('APP_ENV','local'),'offers_configured':False}

    @app.post('/v1/auth/register',tags=['identity'],status_code=201)
    def register(data:s.Register,request:Request,db=DB):
        throttle(request)
        if db.scalar(select(m.Account).where(m.Account.email==data.email)):
            raise RuleError('REGISTRATION_UNAVAILABLE','NÃ£o foi possÃ­vel criar a conta. Entre ou solicite recuperaÃ§Ã£o.',409)
        account=m.Account(email=data.email,password_hash=hash_password(data.password))
        db.add(account); db.flush()
        family=m.Household(name='Minha famÃ­lia',owner_id=account.id)
        db.add(family); db.flush()
        svc.audit(db,account,'account_registered',account.id)
        return {**issue_session(db,account.id),'household_id':family.id,'verification_state':'external_channel_not_configured','environment':'local'}

    @app.post('/v1/auth/session',tags=['identity'])
    def login(data:s.Credentials,request:Request,db=DB):
        throttle(request)
        account=db.scalar(select(m.Account).where(m.Account.email==data.email))
        valid=verify_password(data.password,account.password_hash if account else dummy_password)
        if not account or not valid: raise RuleError('INVALID_CREDENTIALS','E-mail ou senha invÃ¡lidos.',401)
        svc.audit(db,account,'session_started',account.id)
        return issue_session(db,account.id)

    @app.post('/v1/auth/recover',tags=['identity'])
    def recover(data:s.Recovery,request:Request):
        throttle(request)
        return {'message':'Se houver uma conta e um canal de recuperaÃ§Ã£o configurado, enviaremos as instruÃ§Ãµes.', 'delivery_state':'external_channel_not_configured'}

    @app.get('/v1/auth/me',tags=['identity'])
    def me(user=ACTOR): return {'id':user.id,'email':user.email,'created_at':user.created_at}

    @app.post('/v1/auth/refresh',tags=['identity'])
    def refresh(request:Request,user=ACTOR,db=DB):
        current=db.scalar(select(m.AuthSession).where(m.AuthSession.token_hash==request.state.session_hash).with_for_update())
        if current.revoked: raise RuleError('UNAUTHENTICATED','SessÃ£o revogada.',401)
        current.revoked=True
        return issue_session(db,user.id)

    @app.post('/v1/auth/logout',tags=['identity'])
    def logout(request:Request,all_sessions:bool=False,user=ACTOR,db=DB):
        query=select(m.AuthSession).where(m.AuthSession.account_id==user.id)
        if not all_sessions: query=query.where(m.AuthSession.token_hash==request.state.session_hash)
        for session in db.scalars(query.with_for_update()): session.revoked=True
        svc.audit(db,user,'sessions_revoked',user.id)
        return {'revoked':True}

    @app.get('/v1/households',tags=['family'])
    def households(user=ACTOR,db=DB):
        ids={p.household_id for p in svc.accessible_persons(db,user)}
        return {'items':[svc.row(x) for x in db.scalars(select(m.Household).where((m.Household.owner_id==user.id)|(m.Household.id.in_(ids))))]}

    @app.get('/v1/persons',tags=['family'])
    def persons(user=ACTOR,db=DB):
        values=[]
        for person in svc.accessible_persons(db,user):
            family=svc.require(db,m.Household,person.household_id)
            permission=db.scalar(select(m.Permission).where(m.Permission.person_id==person.id,m.Permission.account_id==user.id))
            values.append({**svc.row(person),'local_today':m.now().astimezone(timezone(person.timezone)).date(),'is_owner':family.owner_id==user.id,'scopes':list(SCOPES) if family.owner_id==user.id else permission.scopes})
        return {'items':values}

    @app.post('/v1/households/{household_id}/persons',tags=['family'],status_code=201)
    def create_person(household_id:str,data:s.PersonInput,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        svc.owner(db,user,household_id)
        def operation():
            person=m.Person(household_id=household_id,**data.model_dump())
            db.add(person); db.flush(); svc.audit(db,user,'person_created',person.id)
            return {**svc.row(person),'version':1}
        return svc.command(db,user,idempotency_key,f'person:{household_id}',data.model_dump(),operation)

    @app.patch('/v1/persons/{person_id}/preferences',tags=['family'])
    def preferences(person_id:str,data:s.Preferences,user=ACTOR,db=DB):
        person=svc.require(db,m.Person,person_id,True)
        svc.owner(db,user,person.household_id)
        for key,value in data.model_dump().items(): setattr(person,key,value)
        svc.audit(db,user,'preferences_changed',person.id)
        return svc.row(person)

    @app.get('/v1/persons/{person_id}/permissions',tags=['family'])
    def permissions(person_id:str,user=ACTOR,db=DB):
        person=svc.require(db,m.Person,person_id)
        svc.owner(db,user,person.household_id)
        return {'items':[{**svc.row(p),'account_email':svc.require(db,m.Account,p.account_id).email} for p in db.scalars(select(m.Permission).where(m.Permission.person_id==person_id))]}

    @app.post('/v1/persons/{person_id}/permissions',tags=['family'])
    def delegate(person_id:str,data:s.Delegation,user=ACTOR,db=DB):
        person=svc.require(db,m.Person,person_id)
        svc.owner(db,user,person.household_id)
        target=db.scalar(select(m.Account).where(m.Account.email==data.account_email.lower()))
        if not target: raise RuleError('INVITEE_UNAVAILABLE','A conta deve ser cadastrada antes da concessÃ£o local. Convites por e-mail nÃ£o estÃ£o configurados.',422)
        if target.id==user.id: raise RuleError('INVALID_DELEGATION','O titular jÃ¡ administra este perfil.')
        permission=db.scalar(select(m.Permission).where(m.Permission.person_id==person_id,m.Permission.account_id==target.id).with_for_update())
        if permission: permission.scopes,permission.active=data.scopes,True
        else:
            permission=m.Permission(person_id=person_id,account_id=target.id,scopes=data.scopes)
            db.add(permission)
        db.flush(); svc.audit(db,user,'permission_granted',permission.id)
        return svc.row(permission)

    @app.delete('/v1/persons/{person_id}/permissions/{permission_id}',tags=['family'])
    def revoke(person_id:str,permission_id:str,user=ACTOR,db=DB):
        person=svc.require(db,m.Person,person_id)
        svc.owner(db,user,person.household_id)
        permission=svc.require(db,m.Permission,permission_id,True)
        if permission.person_id!=person_id: raise RuleError('RESOURCE_NOT_FOUND','Registro nÃ£o encontrado.',404)
        permission.active=False; svc.audit(db,user,'permission_revoked',permission.id)
        return {'revoked':True}

    @app.get('/v1/catalog/presentations',tags=['catalog'])
    def catalog(q:str=Query(default='',max_length=160),user=ACTOR):
        return {'items':[],'coverage':'no_authorized_provider','message':'CatÃ¡logo externo nÃ£o configurado. Cadastre manualmente e confirme a apresentaÃ§Ã£o.'}

    @app.get('/v1/persons/{person_id}/medications',tags=['medications'])
    def medications(person_id:str,q:str=Query(default='',max_length=160),limit:int=Query(50,ge=1,le=100),cursor:str|None=None,user=ACTOR,db=DB):
        svc.authorize(db,user,person_id)
        query=select(m.Medication).where(m.Medication.person_id==person_id)
        if q: query=query.where(m.Medication.name.ilike('%'+q.replace('%','\\%').replace('_','\\_')+'%',escape='\\'))
        return page(query,db,limit,cursor)

    @app.post('/v1/persons/{person_id}/medications',tags=['medications'],status_code=201)
    def add_medication(person_id:str,data:s.MedicationInput,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        svc.authorize(db,user,person_id,'manage_plans')
        def operation():
            med=m.Medication(person_id=person_id,**data.model_dump(exclude={'presentation_confirmed'}))
            db.add(med); db.flush(); svc.audit(db,user,'medication_created',med.id)
            return {'medication':svc.row(med),'version':1}
        return svc.command(db,user,idempotency_key,f'medication:{person_id}',data.model_dump(),operation)

    @app.get('/v1/medications/{medication_id}',tags=['medications'])
    def medication_detail(medication_id:str,user=ACTOR,db=DB):
        return svc.row(svc.medication_for(db,user,medication_id))

    @app.get('/v1/medications/{medication_id}/lots',tags=['inventory'])
    def lots(medication_id:str,user=ACTOR,db=DB):
        med=svc.medication_for(db,user,medication_id)
        person=svc.require(db,m.Person,med.person_id)
        today=m.now().astimezone(timezone(person.timezone)).date()
        return {'items':[{**svc.row(x),'balance':svc.balance(db,x.id),'expired':x.expiry_date<today} for x in db.scalars(select(m.Lot).where(m.Lot.medication_id==medication_id).order_by(m.Lot.expiry_date))]}

    @app.post('/v1/medications/{medication_id}/lots',tags=['inventory'],status_code=201)
    def add_lot(medication_id:str,data:s.LotInput,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        med=svc.medication_for(db,user,medication_id,'manage_stock')
        return svc.command(db,user,idempotency_key,f'lot:{medication_id}',data.model_dump(),lambda:svc.new_lot(db,user,med,data,idempotency_key))

    @app.post('/v1/stock-batches/{lot_id}/movements',tags=['inventory'])
    def movement(lot_id:str,data:s.MovementInput,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        lot,med=svc.lot_for(db,user,lot_id,lock=True)
        def operation():
            delta=data.quantity
            if data.unit!=lot.unit: raise RuleError('UNIT_MISMATCH','Unidade incompatÃ­vel com o lote.')
            if data.reason in ('saida_manual','descarte'): delta=-abs(delta)
            elif data.reason in ('entrada_compra','entrada_ajuste') and delta<0: raise RuleError('INVALID_QUANTITY','Entrada exige quantidade positiva.')
            event=svc.post_movement(db,user,lot,delta,data.reason,idempotency_key)
            return {'movement':svc.row(event),'balance':svc.balance(db,lot.id),'version':1}
        return svc.command(db,user,idempotency_key,f'movement:{lot_id}',data.model_dump(),operation)

    @app.post('/v1/movements/{movement_id}/reversal',tags=['inventory'])
    def reverse(movement_id:str,data:s.ReversalInput,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        original=svc.require(db,m.Movement,movement_id)
        lot,_=svc.lot_for(db,user,original.lot_id,lock=True)
        def operation():
            if original.related_event_id or original.reversal_of: raise RuleError('DOSE_CORRECTION_REQUIRED','Consumos de dose devem ser corrigidos no histÃ³rico de doses; estornos nÃ£o podem ser estornados isoladamente.')
            if db.scalar(select(m.Movement).where(m.Movement.reversal_of==original.id)): raise RuleError('STATE_CONFLICT','Movimento jÃ¡ estornado.',409)
            event=svc.post_movement(db,user,lot,-original.delta,'reversao',idempotency_key,reversal_of=original.id)
            return {'movement':svc.row(event),'balance':svc.balance(db,lot.id),'version':1}
        return svc.command(db,user,idempotency_key,f'reverse:{movement_id}',data.model_dump(),operation)

    @app.get('/v1/persons/{person_id}/inventory/history',tags=['inventory'])
    def inventory_history(person_id:str,limit:int=Query(50,ge=1,le=100),cursor:str|None=None,user=ACTOR,db=DB):
        svc.authorize(db,user,person_id)
        meds=select(m.Medication.id).where(m.Medication.person_id==person_id)
        lots_query=select(m.Lot.id).where(m.Lot.medication_id.in_(meds))
        return page(select(m.Movement).where(m.Movement.lot_id.in_(lots_query)),db,limit,cursor)

    @app.get('/v1/persons/{person_id}/plans',tags=['plans'])
    def plans(person_id:str,user=ACTOR,db=DB):
        svc.authorize(db,user,person_id)
        meds=select(m.Medication.id).where(m.Medication.person_id==person_id)
        return {'items':[{**svc.row(p),'active_version':svc.row(svc.active_version(db,p)),'medication':svc.row(svc.require(db,m.Medication,p.medication_id))} for p in db.scalars(select(m.Plan).where(m.Plan.medication_id.in_(meds)))]}

    @app.post('/v1/plans/preview',tags=['plans'])
    def preview(data:s.PlanInput,user=ACTOR):
        end=min(data.end_date or data.start_date+timedelta(days=6),data.start_date+timedelta(days=6))
        return {'items':[{**item,'scheduled_local':item['scheduled_at'].astimezone(timezone(data.timezone)).isoformat()} for item in schedule('preview',data.start_date,end,data.times,data.timezone,data.weekdays)], 'dst_policy':'HorÃ¡rio inexistente Ã© rejeitado; horÃ¡rio ambÃ­guo usa a primeira ocorrÃªncia. PrÃ©via nÃ£o salva plano.'}

    @app.post('/v1/medications/{medication_id}/plans',tags=['plans'],status_code=201)
    def create_plan(medication_id:str,data:s.PlanInput,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        med=svc.medication_for(db,user,medication_id,'manage_plans')
        def operation():
            if data.unit!=med.unit: raise RuleError('UNIT_MISMATCH','Use a unidade cadastrada, sem conversÃ£o automÃ¡tica.')
            list(schedule('validation',data.start_date,min(data.end_date or data.start_date+timedelta(days=30),data.start_date+timedelta(days=30)),data.times,data.timezone,data.weekdays))
            plan=m.Plan(medication_id=med.id)
            db.add(plan);db.flush()
            version=m.PlanVersion(plan_id=plan.id,revision=1,**svc.version_data(data))
            db.add(version);db.flush(); svc.audit(db,user,'plan_created',plan.id)
            return {'plan':svc.row(plan),'active_version':svc.row(version),'version':plan.revision}
        return svc.command(db,user,idempotency_key,f'plan:{medication_id}',data.model_dump(),operation)

    @app.patch('/v1/plans/{plan_id}',tags=['plans'])
    def edit_plan(plan_id:str,data:s.PlanEdit,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        plan=svc.require(db,m.Plan,plan_id,True)
        med=svc.medication_for(db,user,plan.medication_id,'manage_plans')
        def operation():
            if plan.revision!=data.version: raise RuleError('STATE_CONFLICT','Plano alterado em outro dispositivo.',409)
            if data.unit!=med.unit: raise RuleError('UNIT_MISMATCH','Unidade incompatÃ­vel.')
            if data.start_date>m.now().astimezone(timezone(data.timezone)).date(): raise RuleError('EDIT_START_DATE','Neste ciclo, versÃµes editadas entram em vigor hoje. Agendamento de versÃ£o futura permanece pendente.')
            for version in db.scalars(select(m.PlanVersion).where(m.PlanVersion.plan_id==plan.id)):
                for occurrence in db.scalars(select(m.Occurrence).where(m.Occurrence.version_id==version.id,m.Occurrence.scheduled_at>m.now(),m.Occurrence.status.in_(['programada','pendente','sem_confirmacao']))):
                    occurrence.status='cancelada';occurrence.revision+=1
            plan.revision+=1
            plan.active_revision=plan.revision
            plan.status='ativo'
            version=m.PlanVersion(plan_id=plan.id,revision=plan.revision,**svc.version_data(data))
            db.add(version);db.flush();svc.audit(db,user,'plan_versioned',plan.id)
            return {'plan':svc.row(plan),'active_version':svc.row(version),'version':plan.revision}
        return svc.command(db,user,idempotency_key,f'edit-plan:{plan_id}',data.model_dump(),operation)

    @app.post('/v1/plans/{plan_id}/status',tags=['plans'])
    def plan_status(plan_id:str,data:s.PlanStatus,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        plan=svc.require(db,m.Plan,plan_id,True)
        med=svc.medication_for(db,user,plan.medication_id,'manage_plans')
        def operation():
            if plan.revision!=data.version: raise RuleError('STATE_CONFLICT','Atualize o plano para continuar.',409)
            # Aggregate revision advances; the active clinical snapshot stays immutable.
            if data.status=='ativo' and plan.status!='ativo': raise RuleError('NEW_VERSION_REQUIRED','Para retomar, crie uma nova versÃ£o com horÃ¡rios revisados.')
            plan.status=data.status
            plan.revision+=1
            versions=select(m.PlanVersion.id).where(m.PlanVersion.plan_id==plan.id)
            for occurrence in db.scalars(select(m.Occurrence).where(m.Occurrence.version_id.in_(versions),m.Occurrence.scheduled_at>m.now(),m.Occurrence.status.not_in(['tomada_confirmada','nao_tomada_declarada']))):
                occurrence.status='cancelada';occurrence.revision+=1
            svc.audit(db,user,'plan_status_changed',plan.id)
            return {'plan':svc.row(plan),'version':plan.revision}
        return svc.command(db,user,idempotency_key,f'plan-status:{plan_id}',data.model_dump(),operation)

    @app.get('/v1/persons/{person_id}/dose-occurrences',tags=['doses'])
    def doses(person_id:str,start:date,end:date,user=ACTOR,db=DB):
        person=svc.authorize(db,user,person_id)
        svc.materialize(db,person,start,end)
        values=db.scalars(select(m.Occurrence).where(m.Occurrence.person_id==person_id,m.Occurrence.local_date>=start,m.Occurrence.local_date<=end).order_by(m.Occurrence.scheduled_at)).all()
        return {'items':[svc.occurrence_view(db,x,person) for x in values]}

    @app.get('/v1/dose-occurrences/{occurrence_id}',tags=['doses'])
    def dose_detail(occurrence_id:str,user=ACTOR,db=DB):
        occurrence=svc.require(db,m.Occurrence,occurrence_id)
        person=svc.authorize(db,user,occurrence.person_id)
        return {**svc.occurrence_view(db,occurrence,person),'events':[svc.row(x) for x in db.scalars(select(m.DoseEvent).where(m.DoseEvent.occurrence_id==occurrence.id).order_by(m.DoseEvent.created_at))]}

    @app.post('/v1/dose-occurrences/{occurrence_id}/actions',tags=['doses'])
    def take_dose(occurrence_id:str,data:s.DoseAction,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        return svc.dose_action(db,user,occurrence_id,data,idempotency_key)

    @app.post('/v1/dose-occurrences/{occurrence_id}/corrections',tags=['doses'])
    def correct_dose(occurrence_id:str,data:s.Correction,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        return svc.dose_action(db,user,occurrence_id,data,idempotency_key,True)

    @app.post('/v1/sync/commands',tags=['sync'])
    def sync(data:s.SyncBatch,user=ACTOR,db=DB):
        results=[]
        for item in data.commands:
            try:
                with db.begin_nested(): result=svc.dose_action(db,user,item.occurrence_id,item.payload,item.idempotency_key)
                results.append({'idempotency_key':item.idempotency_key,'status':'confirmed','result':result})
            except RuleError as exc:
                results.append({'idempotency_key':item.idempotency_key,'status':'rejected','code':exc.code,'detail':exc.detail,'http_status':exc.status})
            except IntegrityError:
                results.append({'idempotency_key':item.idempotency_key,'status':'rejected','code':'STATE_CONFLICT','http_status':409,'detail':'Evento jÃ¡ registrado. Confira o histÃ³rico.'})
        return {'items':results}

    @app.get('/v1/persons/{person_id}/replenishment',tags=['replenishment'])
    def replenishment(person_id:str,user=ACTOR,db=DB):
        person=svc.authorize(db,user,person_id)
        return {'items':svc.projections(db,user,person)}

    @app.get('/v1/persons/{person_id}/alerts',tags=['replenishment'])
    def alerts(person_id:str,user=ACTOR,db=DB):
        person=svc.authorize(db,user,person_id)
        today=m.now().astimezone(timezone(person.timezone)).date()
        items=[]
        for projection in svc.projections(db,user,person):
            med=projection['medication']
            if projection['eligible_balance']==0 or (projection['days_remaining'] is not None and projection['days_remaining']<=person.low_stock_days):
                items.append({'kind':'low_stock','medication':med,'projection':projection})
            for lot in db.scalars(select(m.Lot).where(m.Lot.medication_id==med['id'],m.Lot.expiry_date<=today+timedelta(days=person.expiry_alert_days))):
                if svc.balance(db,lot.id)>0: items.append({'kind':'expired' if lot.expiry_date<today else 'expiring','medication':med,'lot':svc.row(lot)})
        return {'items':items}

    @app.get('/v1/persons/{person_id}/shopping-items',tags=['shopping'])
    def shopping(person_id:str,user=ACTOR,db=DB):
        svc.authorize(db,user,person_id,'manage_shopping')
        meds=select(m.Medication.id).where(m.Medication.person_id==person_id)
        return {'items':[{**svc.row(x),'medication':svc.row(svc.require(db,m.Medication,x.medication_id))} for x in db.scalars(select(m.ShoppingItem).where(m.ShoppingItem.medication_id.in_(meds)).order_by(m.ShoppingItem.created_at))]}

    @app.post('/v1/shopping-items',tags=['shopping'],status_code=201)
    def add_shopping(data:s.ShoppingInput,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        med=svc.medication_for(db,user,data.medication_id,'manage_shopping')
        def operation():
            db.scalar(select(m.Medication).where(m.Medication.id==med.id).with_for_update())
            if data.unit!=med.unit: raise RuleError('UNIT_MISMATCH','Unidade incompatÃ­vel.')
            existing=db.scalar(select(m.ShoppingItem).where(m.ShoppingItem.medication_id==med.id,m.ShoppingItem.status=='pendente'))
            if existing: raise RuleError('STATE_CONFLICT','Este medicamento jÃ¡ estÃ¡ na lista de compras.',409)
            item=m.ShoppingItem(**data.model_dump())
            db.add(item);db.flush();svc.audit(db,user,'shopping_added',item.id)
            return {'item':svc.row(item),'version':item.revision}
        return svc.command(db,user,idempotency_key,'shopping',data.model_dump(),operation)

    @app.post('/v1/shopping-items/{item_id}/receive',tags=['shopping'])
    def receive(item_id:str,data:s.ReceiveInput,idempotency_key:str=Header(default=''),user=ACTOR,db=DB):
        item=svc.require(db,m.ShoppingItem,item_id,True)
        med=svc.medication_for(db,user,item.medication_id,'manage_shopping')
        svc.authorize(db,user,med.person_id,'manage_stock')
        def operation():
            if item.revision!=data.version or item.status!='pendente': raise RuleError('STATE_CONFLICT','Este item mudou ou jÃ¡ foi recebido.',409)
            result=svc.new_lot(db,user,med,data,idempotency_key)
            item.status='recebimento_confirmado';item.revision+=1
            svc.audit(db,user,'shopping_received',item.id)
            return {**result,'item_id':item.id,'version':item.revision}
        return svc.command(db,user,idempotency_key,f'receive:{item_id}',data.model_dump(),operation)

    @app.delete('/v1/shopping-items/{item_id}',tags=['shopping'])
    def cancel_shopping(item_id:str,user=ACTOR,db=DB):
        item=svc.require(db,m.ShoppingItem,item_id,True)
        svc.medication_for(db,user,item.medication_id,'manage_shopping')
        if item.status=='recebimento_confirmado': raise RuleError('STATE_CONFLICT','Recebimento jÃ¡ confirmado. Ajuste pelo livro de estoque.',409)
        item.status='cancelado';item.revision+=1;svc.audit(db,user,'shopping_cancelled',item.id)
        return svc.row(item)

    @app.get('/v1/offers',tags=['offers'])
    def offers(presentation_id:str=Query(min_length=1,max_length=100),postal_code:str=Query(pattern=r'^\d{8}$'),fulfillment:str=Query(default='retirada',pattern='^(retirada|entrega)$'),user=ACTOR):
        return {'items':[],'coverage':'no_authorized_sources','independent_sources':0,'mvp_gate':'G13_BLOCKED','message':'Nenhuma oferta verificada no momento. SÃ£o necessÃ¡rias duas fontes independentes autorizadas.'}

    @app.get('/v1/privacy/export',tags=['privacy'])
    def export(user=ACTOR,db=DB):
        persons=[p for p in svc.accessible_persons(db,user) if svc.require(db,m.Household,p.household_id).owner_id==user.id]
        ids=[p.id for p in persons]
        meds=db.scalars(select(m.Medication).where(m.Medication.person_id.in_(ids))).all()
        lots=db.scalars(select(m.Lot).where(m.Lot.medication_id.in_([x.id for x in meds]))).all()
        plans=db.scalars(select(m.Plan).where(m.Plan.medication_id.in_([x.id for x in meds]))).all()
        occurrences=db.scalars(select(m.Occurrence).where(m.Occurrence.person_id.in_(ids))).all()
        svc.audit(db,user,'privacy_export',user.id)
        return {'generated_at':m.now(),'account':{'id':user.id,'email':user.email},'persons':[svc.row(x) for x in persons], 'medications':[svc.row(x) for x in meds], 'lots':[svc.row(x) for x in lots], 'movements':[svc.row(x) for x in db.scalars(select(m.Movement).where(m.Movement.lot_id.in_([y.id for y in lots])))], 'plans':[svc.row(x) for x in plans], 'versions':[svc.row(x) for x in db.scalars(select(m.PlanVersion).where(m.PlanVersion.plan_id.in_([y.id for y in plans])))], 'occurrences':[svc.row(x) for x in occurrences], 'dose_events':[svc.row(x) for x in db.scalars(select(m.DoseEvent).where(m.DoseEvent.occurrence_id.in_([y.id for y in occurrences])))], 'shopping':[svc.row(x) for x in db.scalars(select(m.ShoppingItem).where(m.ShoppingItem.medication_id.in_([y.id for y in meds])))]}

    @app.post('/v1/privacy/deletion-requests',tags=['privacy'],status_code=202)
    def deletion(data:s.DeletionRequest,user=ACTOR,db=DB):
        existing=db.scalar(select(m.PrivacyRequest).where(m.PrivacyRequest.account_id==user.id,m.PrivacyRequest.kind=='deletion',m.PrivacyRequest.status=='pending_review'))
        if existing: return svc.row(existing)
        record=m.PrivacyRequest(account_id=user.id,kind='deletion')
        db.add(record);db.flush();svc.audit(db,user,'deletion_requested',record.id)
        return {**svc.row(record),'message':'SolicitaÃ§Ã£o registrada. ExclusÃ£o efetiva e retenÃ§Ã£o dependem de polÃ­tica validada; seus dados ainda nÃ£o foram excluÃ­dos.'}

    web=ROOT/'dist/web'
    if web.exists():
        app.mount('/app',StaticFiles(directory=web,html=True),name='app')
    @app.get('/',include_in_schema=False)
    def index(): return RedirectResponse('/app/')
    def openapi_contract():
        if app.openapi_schema: return app.openapi_schema
        schema=get_openapi(title=app.title,version=app.version,description=app.description,routes=app.routes)
        schema.setdefault('components',{}).setdefault('schemas',{})['Problem']={
            'type':'object','required':['type','title','status','detail','code'],
            'properties':{'type':{'type':'string'},'title':{'type':'string'},'status':{'type':'integer'},'detail':{'type':'string'},'code':{'type':'string'}}}
        schema['components']['securitySchemes']={'bearerAuth':{'type':'http','scheme':'bearer','description':'SessÃ£o opaca com expiraÃ§Ã£o e revogaÃ§Ã£o no servidor.'}}
        for path,operations in schema['paths'].items():
            if not path.startswith('/v1/'): continue
            for operation in operations.values():
                if not isinstance(operation,dict) or 'responses' not in operation: continue
                if path not in ('/v1/auth/register','/v1/auth/session','/v1/auth/recover'):
                    operation['security']=[{'bearerAuth':[]}]
                for status in (400,401,403,404,409,413,422,429,503):
                    operation['responses'][str(status)]={'description':'Erro padronizado sem ecoar dados sensÃ­veis.','content':{'application/problem+json':{'schema':{'$ref':'#/components/schemas/Problem'}}}}
        app.openapi_schema=schema
        return schema
    app.openapi=openapi_contract
    return app

app=create_app()
