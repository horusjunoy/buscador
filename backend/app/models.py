from datetime import UTC, datetime
from uuid import uuid4
from sqlalchemy import Boolean, CheckConstraint, Column, Date, DateTime, ForeignKey, Index, Integer, JSON, Numeric, String, UniqueConstraint
from sqlalchemy.orm import declarative_base

Base = declarative_base()
def uid(): return str(uuid4())
def now(): return datetime.now(UTC)
def identity(): return Column(String(36), primary_key=True, default=uid)
def stamp(): return Column(DateTime(timezone=True), nullable=False, default=now)

class Account(Base):
    __tablename__ = 'accounts'
    id = identity()
    email = Column(String(254), unique=True, nullable=False)
    password_hash = Column(String(300), nullable=False)
    created_at = stamp()

class AuthSession(Base):
    __tablename__ = 'sessions'
    token_hash = Column(String(64), primary_key=True)
    account_id = Column(ForeignKey('accounts.id'), nullable=False, index=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    revoked = Column(Boolean, nullable=False, default=False)
    created_at = stamp()

class Household(Base):
    __tablename__ = 'households'
    id = identity()
    name = Column(String(100), nullable=False)
    owner_id = Column(ForeignKey('accounts.id'), nullable=False, index=True)
    created_at = stamp()

class Person(Base):
    __tablename__ = 'persons'
    id = identity()
    household_id = Column(ForeignKey('households.id'), nullable=False, index=True)
    display_name = Column(String(100), nullable=False)
    timezone = Column(String(80), nullable=False, default='America/Sao_Paulo')
    unconfirmed_minutes = Column(Integer, nullable=False, default=120)
    expiry_alert_days = Column(Integer, nullable=False, default=30)
    low_stock_days = Column(Integer, nullable=False, default=7)
    created_at = stamp()

class Permission(Base):
    __tablename__ = 'permissions'
    id = identity()
    person_id = Column(ForeignKey('persons.id'), nullable=False)
    account_id = Column(ForeignKey('accounts.id'), nullable=False)
    scopes = Column(JSON, nullable=False)
    active = Column(Boolean, nullable=False, default=True)
    __table_args__ = (UniqueConstraint('person_id', 'account_id'),)

class Medication(Base):
    __tablename__ = 'medications'
    id = identity()
    person_id = Column(ForeignKey('persons.id'), nullable=False, index=True)
    name = Column(String(160), nullable=False)
    ingredient = Column(String(160), nullable=False)
    strength = Column(String(80), nullable=False)
    form = Column(String(80), nullable=False)
    unit = Column(String(30), nullable=False)
    pack_quantity = Column(Numeric(14, 3), nullable=False)
    gtin = Column(String(14))
    source = Column(String(30), nullable=False, default='manual_unverified')
    active = Column(Boolean, nullable=False, default=True)
    created_at = stamp()
    __table_args__ = (CheckConstraint('pack_quantity > 0'),)

class Lot(Base):
    __tablename__ = 'stock_lots'
    id = identity()
    medication_id = Column(ForeignKey('medications.id'), nullable=False, index=True)
    lot_code = Column(String(80), nullable=False)
    expiry_date = Column(Date, nullable=False)
    unit = Column(String(30), nullable=False)
    location = Column(String(100), nullable=False, default='')
    created_at = stamp()

class Movement(Base):
    __tablename__ = 'inventory_movements'
    id = identity()
    lot_id = Column(ForeignKey('stock_lots.id'), nullable=False, index=True)
    delta = Column(Numeric(14, 3), nullable=False)
    unit = Column(String(30), nullable=False)
    reason = Column(String(40), nullable=False)
    actor_id = Column(ForeignKey('accounts.id'), nullable=False)
    related_event_id = Column(String(36), unique=True)
    reversal_of = Column(ForeignKey('inventory_movements.id'), unique=True)
    idempotency_key = Column(String(100), nullable=False)
    created_at = stamp()
    __table_args__ = (CheckConstraint('delta != 0'),)

class Plan(Base):
    __tablename__ = 'treatment_plans'
    id = identity()
    medication_id = Column(ForeignKey('medications.id'), nullable=False, index=True)
    status = Column(String(20), nullable=False, default='ativo')
    revision = Column(Integer, nullable=False, default=1)
    active_revision = Column(Integer, nullable=False, default=1)
    created_at = stamp()

class PlanVersion(Base):
    __tablename__ = 'plan_versions'
    id = identity()
    plan_id = Column(ForeignKey('treatment_plans.id'), nullable=False, index=True)
    revision = Column(Integer, nullable=False)
    dose_quantity = Column(Numeric(14, 3), nullable=False)
    unit = Column(String(30), nullable=False)
    times = Column(JSON, nullable=False)
    weekdays = Column(JSON, nullable=False)
    timezone = Column(String(80), nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date)
    source_kind = Column(String(40), nullable=False)
    instructions = Column(String(500), nullable=False, default='')
    created_at = stamp()
    __table_args__ = (UniqueConstraint('plan_id', 'revision'), CheckConstraint('dose_quantity > 0'))

class Occurrence(Base):
    __tablename__ = 'dose_occurrences'
    id = identity()
    version_id = Column(ForeignKey('plan_versions.id'), nullable=False, index=True)
    person_id = Column(ForeignKey('persons.id'), nullable=False, index=True)
    scheduled_at = Column(DateTime(timezone=True), nullable=False)
    local_date = Column(Date, nullable=False)
    timezone = Column(String(80), nullable=False)
    status = Column(String(40), nullable=False, default='programada')
    revision = Column(Integer, nullable=False, default=1)
    remind_at = Column(DateTime(timezone=True))
    stock_reconciliation_required = Column(Boolean, nullable=False, default=False)
    __table_args__ = (UniqueConstraint('version_id', 'scheduled_at'), Index('occurrence_person_date', 'person_id', 'local_date'))

class DoseEvent(Base):
    __tablename__ = 'dose_events'
    id = identity()
    occurrence_id = Column(ForeignKey('dose_occurrences.id'), nullable=False, index=True)
    actor_id = Column(ForeignKey('accounts.id'), nullable=False)
    action = Column(String(40), nullable=False)
    occurred_at = Column(DateTime(timezone=True), nullable=False)
    created_at = stamp()
    client_event_id = Column(String(36), nullable=False)
    idempotency_key = Column(String(100), nullable=False)
    supersedes_id = Column(ForeignKey('dose_events.id'))
    __table_args__ = (UniqueConstraint('actor_id', 'client_event_id'),)

class CommandReceipt(Base):
    __tablename__ = 'command_receipts'
    id = identity()
    actor_id = Column(ForeignKey('accounts.id'), nullable=False)
    key = Column(String(100), nullable=False)
    fingerprint = Column(String(64), nullable=False)
    response = Column(JSON, nullable=False)
    created_at = stamp()
    __table_args__ = (UniqueConstraint('actor_id', 'key'),)

class ShoppingItem(Base):
    __tablename__ = 'shopping_items'
    id = identity()
    medication_id = Column(ForeignKey('medications.id'), nullable=False, index=True)
    quantity = Column(Numeric(14, 3), nullable=False)
    unit = Column(String(30), nullable=False)
    status = Column(String(40), nullable=False, default='pendente')
    revision = Column(Integer, nullable=False, default=1)
    created_at = stamp()
    __table_args__ = (CheckConstraint('quantity > 0'),)

class AuditEvent(Base):
    __tablename__ = 'audit_events'
    id = identity()
    actor_id = Column(ForeignKey('accounts.id'), nullable=False, index=True)
    action = Column(String(80), nullable=False)
    resource_id = Column(String(36), nullable=False)
    created_at = stamp()

class PrivacyRequest(Base):
    __tablename__ = 'privacy_requests'
    id = identity()
    account_id = Column(ForeignKey('accounts.id'), nullable=False)
    kind = Column(String(20), nullable=False)
    status = Column(String(30), nullable=False, default='pending_review')
    created_at = stamp()
