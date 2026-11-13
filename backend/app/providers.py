"""Provider contracts and admissibility rules. No retailer is configured by default."""
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Protocol
from urllib.parse import urlsplit
from .domain import RuleError, utc

@dataclass(frozen=True)
class Presentation:
    id: str
    ingredient: str
    strength: str
    form: str
    pack_quantity: Decimal
    unit: str

@dataclass(frozen=True)
class SourceAuthorization:
    id: str
    independent_retailer_id: str
    allowed_domains: frozenset[str]
    evidence_reference: str
    terms_verified_at: datetime
    valid_until: datetime

@dataclass(frozen=True)
class ProviderOffer:
    source: SourceAuthorization
    external_product_id: str
    presentation: Presentation
    item_price: Decimal
    shipping: Decimal | None
    fees: Decimal | None
    availability: str
    channel: str
    conditions: tuple[str,...]
    retrieved_at: datetime
    expires_at: datetime
    source_url: str
    currency: str = 'BRL'

class CatalogProvider(Protocol):
    async def search(self, query: str) -> list[Presentation]: ...

class OffersProvider(Protocol):
    authorization: SourceAuthorization
    async def search(self, presentation: Presentation, postal_code: str, fulfillment: str) -> list[ProviderOffer]: ...

def safe_url(value: str, domains: frozenset[str]):
    parsed=urlsplit(value)
    if parsed.scheme!='https' or not parsed.hostname or parsed.username or parsed.password or parsed.port not in (None,443):
        raise RuleError('UNVERIFIED_OFFER_URL','Destino comercial não autorizado.')
    host=parsed.hostname.encode('idna').decode('ascii').lower()
    if host not in domains or parsed.fragment:
        raise RuleError('UNVERIFIED_OFFER_URL','Destino comercial não autorizado.')
    return value

def compare_offers(requested: Presentation, offers: list[ProviderOffer], now: datetime):
    current=[];partial=[];alternatives=[];rejected=[];sources=set()
    for offer in offers:
        try:
            source=offer.source
            if not source.evidence_reference or utc(source.terms_verified_at)>utc(now) or utc(source.valid_until)<=utc(now):
                raise RuleError('SOURCE_NOT_AUTHORIZED','Fonte sem autorização vigente.')
            safe_url(offer.source_url,source.allowed_domains)
            if utc(offer.retrieved_at)>utc(now)+timedelta(minutes=1) or utc(offer.expires_at)<=utc(now) or utc(offer.expires_at)<=utc(offer.retrieved_at):
                raise RuleError('EXPIRED_OFFER','Oferta fora de validade.')
            prices=[offer.item_price]+[x for x in (offer.shipping,offer.fees) if x is not None]
            if any(not x.is_finite() or x<0 or x!=x.quantize(Decimal('.01')) for x in prices) or offer.currency!='BRL':
                raise RuleError('INVALID_OFFER_PRICE','Preço ou moeda inválidos.')
            exact=requested.id==offer.presentation.id and (requested.ingredient,requested.strength,requested.form,requested.pack_quantity,requested.unit)==(offer.presentation.ingredient,offer.presentation.strength,offer.presentation.form,offer.presentation.pack_quantity,offer.presentation.unit)
            complete=offer.shipping is not None and offer.fees is not None
            item={'source_id':source.id,'source_terms_verified':True,'independent_retailer_id':source.independent_retailer_id,
                'source_product_id':offer.external_product_id,'canonical_presentation_id':requested.id,
                'offered_presentation_id':offer.presentation.id,'offered_strength':offer.presentation.strength,
                'offered_form':offer.presentation.form,'offered_pack_quantity':str(offer.presentation.pack_quantity),'offered_unit':offer.presentation.unit,
                'match_type':'exact_match' if exact else 'alternative_requires_review',
                'unit_price':str(offer.item_price),'currency':offer.currency,
                'delivery_fee':str(offer.shipping) if offer.shipping is not None else None,
                'fees':str(offer.fees) if offer.fees is not None else None,
                'total_cost':str(offer.item_price+offer.shipping+offer.fees) if complete else None,
                'available_state':offer.availability,'retail_channel':offer.channel,
                'eligible_conditions':list(offer.conditions),'retrieved_at':offer.retrieved_at,'expires_at':offer.expires_at,
                'source_url':offer.source_url,'price_label':'custo_conhecido_condicionado' if complete else 'valor_parcial'}
            if not exact: alternatives.append(item)
            elif not complete or offer.availability!='em_estoque': partial.append(item)
            else: current.append(item);sources.add(source.independent_retailer_id)
        except (RuleError,ValueError) as exc:
            rejected.append({'source_id':offer.source.id,'code':exc.code if isinstance(exc,RuleError) else 'INVALID_OFFER_URL'})
    # Conditions remain visible; the caller must apply user eligibility before claiming savings.
    current.sort(key=lambda x:Decimal(x['total_cost']))
    return {'items':current,'partial':partial,'alternatives':alternatives,'rejected':rejected,
            'independent_sources':len(sources),'pilot_two_source_gate':len(sources)>=2}
