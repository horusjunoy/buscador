from datetime import date, datetime
from decimal import Decimal
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from .domain import positive, quantity, timezone, SCOPES

Unit = Literal['comprimido', 'capsula', 'mL', 'gota', 'dose', 'frasco', 'unidade']

class Input(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)

class Credentials(Input):
    email: str = Field(min_length=5, max_length=254, pattern=r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
    password: str = Field(min_length=12, max_length=128)
    @field_validator('email')
    @classmethod
    def normalize_email(cls, v): return v.lower()

class Register(Credentials):
    privacy_acknowledged: Literal[True]

class Recovery(Input):
    email: str = Field(min_length=5, max_length=254)

class PersonInput(Input):
    display_name: str = Field(min_length=1, max_length=100)
    timezone: str = 'America/Sao_Paulo'
    @field_validator('timezone')
    @classmethod
    def valid_tz(cls, v): timezone(v); return v

class Preferences(Input):
    unconfirmed_minutes: int = Field(ge=15, le=1440)
    expiry_alert_days: int = Field(ge=0, le=365)
    low_stock_days: int = Field(ge=0, le=90)

class Delegation(Input):
    account_email: str = Field(min_length=5, max_length=254)
    scopes: list[str] = Field(max_length=5)
    @field_validator('scopes')
    @classmethod
    def valid_scopes(cls, v):
        if not set(v).issubset(SCOPES): raise ValueError('Permissão desconhecida')
        return sorted(set(v))

class MedicationInput(Input):
    name: str = Field(min_length=1, max_length=160)
    ingredient: str = Field(min_length=1, max_length=160)
    strength: str = Field(min_length=1, max_length=80)
    form: str = Field(min_length=1, max_length=80)
    unit: Unit
    pack_quantity: Decimal
    gtin: str | None = Field(default=None, pattern=r'^(\d{8}|\d{12}|\d{13}|\d{14})$')
    presentation_confirmed: Literal[True]
    @field_validator('pack_quantity')
    @classmethod
    def valid_qty(cls, v): return positive(v)

class LotInput(Input):
    lot_code: str = Field(min_length=1, max_length=80)
    expiry_date: date
    quantity: Decimal
    unit: Unit
    location: str = Field(default='', max_length=100)
    @field_validator('quantity')
    @classmethod
    def valid_qty(cls, v): return positive(v)

class MovementInput(Input):
    quantity: Decimal
    unit: Unit
    reason: Literal['entrada_compra', 'entrada_ajuste', 'saida_manual', 'descarte', 'ajuste_auditado']
    confirmed: Literal[True]
    @field_validator('quantity')
    @classmethod
    def valid_qty(cls, v):
        if quantity(v) == 0: raise ValueError('Quantidade não pode ser zero')
        return quantity(v)

class ReversalInput(Input):
    confirmed: Literal[True]

class PlanInput(Input):
    dose_quantity: Decimal
    unit: Unit
    times: list[str] = Field(min_length=1, max_length=12)
    weekdays: list[int] = Field(min_length=1, max_length=7)
    timezone: str
    start_date: date
    end_date: date | None = None
    source_kind: Literal['orientacao_informada', 'receita_informada', 'responsavel_informou']
    instructions: str = Field(default='', max_length=500)
    instructions_confirmed: Literal[True]
    @field_validator('dose_quantity')
    @classmethod
    def valid_qty(cls, v): return positive(v)
    @field_validator('times')
    @classmethod
    def valid_times(cls, v):
        import re
        if any(not re.fullmatch(r'(?:[01]\d|2[0-3]):[0-5]\d', x) for x in v): raise ValueError('Use HH:MM')
        if len(set(v)) != len(v): raise ValueError('Horários duplicados')
        return sorted(v)
    @field_validator('weekdays')
    @classmethod
    def valid_days(cls, v):
        if any(x<0 or x>6 for x in v) or len(set(v))!=len(v): raise ValueError('Dias devem ser únicos, de 0 a 6')
        return sorted(v)
    @field_validator('timezone')
    @classmethod
    def valid_tz(cls, v): timezone(v); return v
    @model_validator(mode='after')
    def valid_period(self):
        if self.end_date and self.end_date < self.start_date: raise ValueError('Fim anterior ao início')
        return self

class PlanEdit(PlanInput):
    version: int = Field(ge=1)

class PlanStatus(Input):
    version: int = Field(ge=1)
    status: Literal['ativo', 'suspenso', 'concluido']
    confirmed: Literal[True]

class DoseAction(Input):
    action: Literal['tomada_confirmada', 'nao_tomada_declarada', 'adiada']
    version: int = Field(ge=1)
    client_event_id: str = Field(min_length=36, max_length=36)
    occurred_at: datetime
    lot_id: str | None = Field(default=None, min_length=36, max_length=36)
    snooze_minutes: int | None = Field(default=None, ge=1, le=120)
    confirmed: Literal[True]
    @field_validator('occurred_at')
    @classmethod
    def aware(cls, v):
        if v.tzinfo is None: raise ValueError('Informe um instante com fuso')
        return v
    @field_validator('client_event_id')
    @classmethod
    def valid_id(cls, v):
        from uuid import UUID
        return str(UUID(v))
    @model_validator(mode='after')
    def snooze_required(self):
        if self.action == 'adiada' and self.snooze_minutes is None: raise ValueError('Informe o adiamento')
        if self.action != 'tomada_confirmada' and self.lot_id: raise ValueError('Esta ação não consome lote')
        return self

class Correction(DoseAction):
    corrects_event_id: str = Field(min_length=36, max_length=36)

class ShoppingInput(Input):
    medication_id: str = Field(min_length=36, max_length=36)
    quantity: Decimal
    unit: Unit
    @field_validator('quantity')
    @classmethod
    def valid_qty(cls, v): return positive(v)

class ReceiveInput(LotInput):
    version: int = Field(ge=1)
    received_confirmed: Literal[True]

class SyncCommand(Input):
    occurrence_id: str = Field(min_length=36, max_length=36)
    idempotency_key: str = Field(min_length=8, max_length=100)
    payload: DoseAction

class SyncBatch(Input):
    commands: list[SyncCommand] = Field(min_length=1, max_length=50)

class DeletionRequest(Input):
    confirmed: Literal[True]
