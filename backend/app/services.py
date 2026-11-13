import hashlib
import json
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from fastapi.encoders import jsonable_encoder
from sqlalchemy import select, func
from . import models as m
from .domain import RuleError, FINAL_STATES, dose_state, positive, quantity, schedule, timezone, utc

def row(model):
    return {col.name: getattr(model, col.name) for col in model.__table__.columns}

def require(db, cls, resource_id, lock=False):
    query = select(cls).where(cls.id == resource_id)
    resource = db.scalar(query.with_for_update() if lock else query)
    if resource is None: raise RuleError('RESOURCE_NOT_FOUND', 'Registro não encontrado.', 404)
    return resource

def authorize(db, actor, person_id, scope='view_medications'):
    person = require(db, m.Person, person_id)
    family = require(db, m.Household, person.household_id)
    if family.owner_id == actor.id: return person
    permission = db.scalar(select(m.Permission).where(m.Permission.person_id==person_id, m.Permission.account_id==actor.id).with_for_update())
    if permission is None or not permission.active or scope not in permission.scopes:
        raise RuleError('RESOURCE_NOT_FOUND', 'Registro não encontrado ou acesso revogado.', 404)
    return person

def owner(db, actor, household_id):
    family = require(db, m.Household, household_id)
    if family.owner_id != actor.id: raise RuleError('RESOURCE_NOT_FOUND', 'Família não encontrada ou sem permissão de administração.', 404)
    return family

def accessible_persons(db, actor):
    owned = select(m.Household.id).where(m.Household.owner_id==actor.id)
    granted = select(m.Permission.person_id).where(m.Permission.account_id==actor.id, m.Permission.active.is_(True))
    return db.scalars(select(m.Person).where((m.Person.household_id.in_(owned)) | (m.Person.id.in_(granted))).order_by(m.Person.created_at)).all()

def audit(db, actor, action, resource_id):
    db.add(m.AuditEvent(actor_id=actor.id, action=action, resource_id=resource_id))

def command(db, actor, key, target, payload, operation):
    if not key or len(key)<8 or len(key)>100 or not all(x.isalnum() or x in '-_' for x in key):
        raise RuleError('IDEMPOTENCY_REQUIRED', 'Informe Idempotency-Key de 8 a 100 caracteres.', 400)
    # Serialize the same actor; independent actors also lock each domain aggregate.
    db.scalar(select(m.Account).where(m.Account.id==actor.id).with_for_update())
    fingerprint = hashlib.sha256(json.dumps(jsonable_encoder({'target':target,'payload':payload}), sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    existing = db.scalar(select(m.CommandReceipt).where(m.CommandReceipt.actor_id==actor.id, m.CommandReceipt.key==key))
    if existing:
        if existing.fingerprint != fingerprint: raise RuleError('IDEMPOTENCY_CONFLICT', 'Esta chave já foi usada para outro comando.', 409)
        return existing.response
    response = operation()
    db.flush()
    response = jsonable_encoder({**response, 'idempotency_key': key, 'recorded_at': m.now(), 'sync_state':'confirmed'})
    db.add(m.CommandReceipt(actor_id=actor.id, key=key, fingerprint=fingerprint, response=response))
    db.flush()
    return response

def balance(db, lot_id):
    return quantity(db.scalar(select(func.coalesce(func.sum(m.Movement.delta), 0)).where(m.Movement.lot_id==lot_id)))

def medication_for(db, actor, medication_id, scope='view_medications'):
    med = require(db, m.Medication, medication_id)
    authorize(db, actor, med.person_id, scope)
    return med

def lot_for(db, actor, lot_id, scope='manage_stock', lock=False):
    lot = require(db, m.Lot, lot_id, lock)
    med = medication_for(db, actor, lot.medication_id, scope)
    return lot, med

def post_movement(db, actor, lot, delta, reason, key, event_id=None, reversal_of=None):
    delta = quantity(delta)
    if balance(db, lot.id) + delta < 0:
        raise RuleError('INSUFFICIENT_STOCK', 'Saldo insuficiente. Confira o lote e registre a conciliação.')
    movement = m.Movement(lot_id=lot.id, delta=delta, reason=reason, unit=lot.unit,
        actor_id=actor.id, related_event_id=event_id, reversal_of=reversal_of, idempotency_key=key)
    db.add(movement); db.flush()
    audit(db, actor, reason, movement.id)
    return movement

def new_lot(db, actor, med, data, key):
    if data.unit != med.unit: raise RuleError('UNIT_MISMATCH', 'A unidade deve ser a mesma do medicamento. Não há conversão automática.')
    lot = m.Lot(medication_id=med.id, lot_code=data.lot_code, expiry_date=data.expiry_date, unit=data.unit, location=data.location)
    db.add(lot); db.flush()
    movement = post_movement(db, actor, lot, data.quantity, 'entrada_compra', key)
    return {'lot': row(lot), 'movement_id':movement.id, 'balance':balance(db, lot.id), 'version':1}

def version_data(data):
    return {k:v for k,v in data.model_dump().items() if k not in ('instructions_confirmed','version')}

def active_version(db, plan):
    return db.scalar(select(m.PlanVersion).where(m.PlanVersion.plan_id==plan.id, m.PlanVersion.revision==plan.active_revision))

def materialize(db, person, start, end):
    if end<start or (end-start).days>92:
        raise RuleError('INVALID_PERIOD','Consulte um período de até 93 dias.')
    # Person lock protects deterministic occurrence insertions across sessions/devices.
    db.scalar(select(m.Person).where(m.Person.id==person.id).with_for_update())
    meds = select(m.Medication.id).where(m.Medication.person_id==person.id)
    plans = db.scalars(select(m.Plan).where(m.Plan.medication_id.in_(meds), m.Plan.status=='ativo')).all()
    for plan in plans:
        version = active_version(db, plan)
        first, last = max(start, version.start_date), min(end, version.end_date or end)
        if first>last: continue
        for data in schedule(version.id, first, last, version.times, version.timezone, version.weekdays):
            if utc(data['scheduled_at']) < utc(version.created_at) and version.revision>1: continue
            if db.get(m.Occurrence, data['id']) is None:
                db.add(m.Occurrence(**data, version_id=version.id, person_id=person.id))
    db.flush()

def occurrence_view(db, occurrence, person):
    version = require(db, m.PlanVersion, occurrence.version_id)
    plan = require(db, m.Plan, version.plan_id)
    med = require(db, m.Medication, plan.medication_id)
    status=dose_state(occurrence.status, occurrence.scheduled_at, m.now(), person.unconfirmed_minutes)
    if occurrence.status=='adiada' and occurrence.remind_at and utc(occurrence.remind_at)<=m.now():
        status=dose_state('programada', occurrence.remind_at, m.now(), person.unconfirmed_minutes)
    return {**row(occurrence), 'person_display_name':person.display_name, 'status':status, 'scheduled_local':utc(occurrence.scheduled_at).astimezone(timezone(occurrence.timezone)).isoformat(),
        'medication':row(med), 'dose_quantity':version.dose_quantity, 'unit':version.unit, 'plan_revision':version.revision}

def dose_action(db, actor, occurrence_id, data, key, correction=False):
    occurrence = require(db, m.Occurrence, occurrence_id, True)
    person = authorize(db, actor, occurrence.person_id, 'record_doses')
    # Re-check authorization BEFORE accepting an idempotency replay after revocation.
    def operation():
        if occurrence.revision != data.version:
            raise RuleError('STATE_CONFLICT', 'Esta dose mudou em outro dispositivo. Atualize para conferir.', 409)
        if utc(data.occurred_at)>m.now()+timedelta(minutes=5):
            raise RuleError('INVALID_EVENT_TIME', 'O horário informado está no futuro.')
        if data.action=='tomada_confirmada' and (utc(occurrence.scheduled_at)>m.now()+timedelta(minutes=5) or utc(data.occurred_at)<utc(occurrence.scheduled_at)-timedelta(minutes=5)):
            raise RuleError('FUTURE_DOSE', 'Não confirme antecipadamente uma dose futura neste ambiente.')
        previous = None
        if correction:
            previous = require(db, m.DoseEvent, data.corrects_event_id)
            latest = db.scalar(select(m.DoseEvent).where(m.DoseEvent.occurrence_id==occurrence.id).order_by(m.DoseEvent.created_at.desc(),m.DoseEvent.id.desc()))
            if previous.occurrence_id!=occurrence.id or latest.id!=previous.id:
                raise RuleError('STATE_CONFLICT', 'A correção deve apontar o último evento desta dose.',409)
            original_movement = db.scalar(select(m.Movement).where(m.Movement.related_event_id==previous.id))
            if original_movement:
                # Dose permission alone cannot change arbitrary stock: only its own linked consumption.
                lot = require(db, m.Lot, original_movement.lot_id, True)
                post_movement(db, actor, lot, -original_movement.delta, 'reversao', key, reversal_of=original_movement.id)
        elif occurrence.status in FINAL_STATES:
            raise RuleError('STATE_CONFLICT', 'Esta dose já possui um registro final. Use a correção auditável.',409)
        version = require(db, m.PlanVersion, occurrence.version_id)
        plan = require(db, m.Plan, version.plan_id)
        event = m.DoseEvent(occurrence_id=occurrence.id, actor_id=actor.id, action=data.action,
            occurred_at=utc(data.occurred_at), client_event_id=data.client_event_id, idempotency_key=key,
            supersedes_id=previous.id if previous else None)
        db.add(event); db.flush()
        effect = 'not_applicable'
        movement_id = None
        occurrence.stock_reconciliation_required = False
        if data.action=='tomada_confirmada':
            effect = 'pending_reconciliation'
            # An explicit physical lot is always required. No silent FEFO allocation.
            if data.lot_id:
                lot = require(db, m.Lot, data.lot_id, True)
                if lot.medication_id != plan.medication_id: raise RuleError('LOT_MISMATCH', 'Este lote não pertence à apresentação da dose.')
                local_today = m.now().astimezone(timezone(person.timezone)).date()
                if lot.unit!=version.unit: raise RuleError('UNIT_MISMATCH','Unidades incompatíveis.')
                if lot.expiry_date < local_today: raise RuleError('EXPIRED_LOT', 'Lote vencido. Confirme o uso sem alocar o lote e confira a conciliação.')
                if balance(db, lot.id) >= version.dose_quantity:
                    movement = post_movement(db, actor, lot, -version.dose_quantity,'consumo_confirmado',key,event.id)
                    movement_id, effect = movement.id, 'posted'
            occurrence.stock_reconciliation_required = effect=='pending_reconciliation'
        occurrence.status = data.action
        occurrence.remind_at = m.now()+timedelta(minutes=data.snooze_minutes) if data.action=='adiada' else None
        occurrence.revision += 1
        audit(db, actor, 'dose_correction' if correction else 'dose_action', event.id)
        return {'event_id':event.id, 'occurrence_id':occurrence.id, 'status':occurrence.status,
            'version':occurrence.revision,'inventory_effect':effect,'movement_id':movement_id,
            'remind_at':occurrence.remind_at,'stock_reconciliation_required':occurrence.stock_reconciliation_required}
    return command(db, actor, key, f'dose:{occurrence_id}:correction={correction}',data.model_dump(),operation)

def projections(db, actor, person, horizon=90):
    today = m.now().astimezone(timezone(person.timezone)).date()
    materialize(db, person, today, today+timedelta(days=horizon))
    meds = db.scalars(select(m.Medication).where(m.Medication.person_id==person.id, m.Medication.active.is_(True))).all()
    result = []
    for med in meds:
        lots = db.scalars(select(m.Lot).where(m.Lot.medication_id==med.id).order_by(m.Lot.expiry_date,m.Lot.id)).all()
        physical = sum((balance(db,x.id) for x in lots), Decimal(0))
        remaining = {x.id:balance(db,x.id) for x in lots if x.expiry_date>=today}
        eligible = sum(remaining.values(),Decimal(0))
        expired = physical-eligible
        versions = select(m.PlanVersion.id).join(m.Plan).where(m.Plan.medication_id==med.id, m.Plan.status=='ativo',m.PlanVersion.revision==m.Plan.active_revision)
        occurrences = db.scalars(select(m.Occurrence).where(m.Occurrence.version_id.in_(versions),m.Occurrence.local_date>=today,m.Occurrence.local_date<=today+timedelta(days=horizon)).order_by(m.Occurrence.scheduled_at)).all()
        depletion = None
        demand = Decimal(0)
        for occurrence in occurrences:
            if occurrence.status in FINAL_STATES or utc(occurrence.scheduled_at)<m.now(): continue
            version = require(db,m.PlanVersion,occurrence.version_id)
            needed = version.dose_quantity
            demand += needed
            # FEFO here is a projection assumption only; it never writes a movement.
            for lot in lots:
                if lot.id not in remaining or lot.expiry_date<occurrence.local_date: continue
                take = min(remaining[lot.id],needed)
                remaining[lot.id]-=take; needed-=take
            if needed>0 and depletion is None: depletion=occurrence.local_date
        result.append({'medication':row(med),'physical_balance':physical,'eligible_balance':eligible,
            'expired_balance':expired,'planned_demand':demand,'depletion_date':depletion,
            'days_remaining':(depletion-today).days if depletion else None,
            'horizon_days':horizon,'assumptions':['Horários cadastrados, sem inferir uso.', 'Lotes vencidos excluídos; FEFO apenas na simulação.', 'Saldo físico permanece inalterado.'],
            'quality':'estimativa_com_plano' if occurrences else 'sem_plano'})
    return result
