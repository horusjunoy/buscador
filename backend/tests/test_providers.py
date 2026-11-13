from dataclasses import replace
from datetime import UTC, datetime, timedelta
from decimal import Decimal
import pytest
from backend.app.providers import Presentation, SourceAuthorization, ProviderOffer, compare_offers, safe_url
from backend.app.domain import RuleError

def example():
    now=datetime.now(UTC)
    presentation=Presentation('synthetic','QA','1 QA','comprimido',Decimal('30'),'comprimido')
    source=SourceAuthorization('synthetic-source','synthetic-retailer',frozenset({'pharmacy.synthetic.invalid'}),'TEST_ONLY',now-timedelta(days=1),now+timedelta(days=1))
    offer=ProviderOffer(source,'TEST',presentation,Decimal('10.00'),Decimal('2.00'),Decimal('0.00'),'em_estoque','entrega',('Dados sintéticos somente em teste.',),now,now+timedelta(minutes=5),'https://pharmacy.synthetic.invalid/item')
    return now,presentation,offer

def test_unknown_freight_does_not_enter_final_price_ranking():
    now,presentation,offer=example()
    result=compare_offers(presentation,[replace(offer,shipping=None)],now)
    assert result['items']==[] and result['partial'][0]['total_cost'] is None
    assert not result['pilot_two_source_gate']

def test_independence_matching_expiry_and_total():
    now,presentation,offer=example()
    different=replace(offer,presentation=replace(presentation,strength='2 QA'))
    stale=replace(offer,expires_at=now-timedelta(seconds=1))
    same_retailer=replace(offer,source=replace(offer.source,id='second-feed'))
    other=replace(offer,source=replace(offer.source,id='other',independent_retailer_id='other-retailer'),shipping=Decimal('1.00'))
    result=compare_offers(presentation,[offer,different,stale,same_retailer,other],now)
    assert len(result['alternatives'])==1 and len(result['rejected'])==1
    assert result['independent_sources']==2 and result['pilot_two_source_gate']
    assert result['items'][0]['total_cost']=='11.00'

@pytest.mark.parametrize('url',['http://pharmacy.synthetic.invalid/a','https://pharmacy.synthetic.invalid.attacker.invalid/a','https://user:secret@pharmacy.synthetic.invalid/a','https://127.0.0.1/a','https://pharmacy.synthetic.invalid:8080/a'])
def test_external_link_is_strictly_allowlisted(url):
    with pytest.raises(RuleError):safe_url(url,frozenset({'pharmacy.synthetic.invalid'}))
