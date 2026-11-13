"""Deterministic rules. No framework, network, or clinical inference."""
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from uuid import UUID, uuid5

UNITS = ('comprimido', 'capsula', 'mL', 'gota', 'dose', 'frasco', 'unidade')
SCOPES = ('view_medications', 'record_doses', 'manage_stock', 'manage_plans', 'manage_shopping')
FINAL_STATES = ('tomada_confirmada', 'nao_tomada_declarada', 'cancelada')
NAMESPACE = UUID('6e70e708-ed02-48b8-9f90-e3d60e45c573')

class RuleError(Exception):
    def __init__(self, code: str, detail: str, status: int = 422):
        self.code, self.detail, self.status = code, detail, status

def utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)  # DB's UTC-naive SQLite representation only.
    return value.astimezone(UTC)

def quantity(value) -> Decimal:
    try:
        result = Decimal(str(value))
    except Exception:
        raise RuleError('INVALID_QUANTITY', 'Informe uma quantidade decimal válida.')
    if not result.is_finite() or abs(result) > Decimal('100000000') or result != result.quantize(Decimal('.001')):
        raise RuleError('INVALID_QUANTITY', 'Use até três casas decimais e quantidade limitada.')
    return result

def timezone(name: str) -> ZoneInfo:
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError):
        raise RuleError('INVALID_TIMEZONE', 'Informe um fuso IANA válido.')

def schedule(version_id: str, start: date, end: date, times: list[str], tz: str, weekdays: list[int]):
    """Wall-clock schedule. DST gaps rejected; ambiguous times use first occurrence.

    Never silently move a nonexistent local time. Policy explicitly visible in preview.
    """
    zone = timezone(tz)
    if end < start or (end-start).days > 92:
        raise RuleError('INVALID_PERIOD', 'Consulte um período de até 93 dias.')
    day = start
    while day <= end:
        if day.weekday() in weekdays:
            for clock in sorted(set(times)):
                naive = datetime.fromisoformat(f'{day.isoformat()}T{clock}:00')
                local = naive.replace(tzinfo=zone, fold=0)
                instant = local.astimezone(UTC)
                if instant.astimezone(zone).replace(tzinfo=None) != naive:
                    raise RuleError('NONEXISTENT_LOCAL_TIME', 'Horário inexistente neste fuso. Revise a agenda informada.')
                yield {'id': str(uuid5(NAMESPACE, f'{version_id}:{instant.isoformat()}')),
                       'scheduled_at': instant, 'local_date': day, 'timezone': tz}
        day += timedelta(days=1)

def dose_state(stored: str, scheduled: datetime, now: datetime, window_minutes: int) -> str:
    if stored in FINAL_STATES or stored == 'adiada':
        return stored
    if utc(now) >= utc(scheduled) + timedelta(minutes=window_minutes):
        return 'sem_confirmacao'
    return 'pendente' if utc(now) >= utc(scheduled) else 'programada'

def positive(value) -> Decimal:
    result = quantity(value)
    if result <= 0:
        raise RuleError('INVALID_QUANTITY', 'A quantidade deve ser maior que zero.')
    return result
