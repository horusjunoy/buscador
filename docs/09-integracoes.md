# 09 — Estratégia de integração com catálogos e farmácias

**Versão:** 0.1 · **Status:** A VALIDAR · **Regra:** nenhuma API/contrato de preços está confirmado nesta documentação.

## Distinção fundamental

1. **Catálogo de medicamentos:** descreve o que um produto é (nome, princípio ativo, concentração, forma, embalagem, registro, GTIN quando disponível).
2. **Preço regulado:** como PMC da CMED, informa teto permitido, **não preço promocional ou oferta de uma farmácia**.
3. **Oferta comercial real:** preço praticado por varejista para uma apresentação, com condições e data/hora de observação.
4. **Disponibilidade:** informação de estoque/retirada/entrega, com região e confiança próprias. Não pode ser inferida só por existir preço.

A Anvisa disponibiliza consultas de registros e bulário, e a CMED divulga tetos. A existência de portal público **não equivale a autorização de coleta automatizada ou a API comercial utilizável**.

## Fontes potenciais e suas funções

| Fonte/canal | Possível uso | Status inicial | Atenção |
|---|---|---|---|
| Anvisa — Sistema de Consultas | Validar produto e registro | Oficial, viabilidade de automação a validar | Consulta pública não é contrato de API |
| Anvisa — Bulário | Referência documental | Oficial, uso e direitos a validar | Não gerar orientação terapêutica |
| CMED — Preços | Exibir referência regulatória de teto | Fonte oficial identificada | PMC ≠ preço ao consumidor cobrado |
| Redes farmacêuticas/parceiros | Preço real, frete, disponibilidade | **Não contratado** | APIs, licença, cobertura e custos a negociar |
| Comparadores/agregadores de ofertas | Preços de múltiplos lojistas | **Não contratado** | Validação de atualização e termos |
| Cadastro manual | Operar sem dados externos | Viável como funcionalidade própria | Não qualifica registro ou preço como validado |

## Estratégia em fases

### Fase A — Catálogo mínimo

- Permitir cadastro manual com apresentação explícita.
- Investigar base pública/fornecedor comercial licenciado para busca por nome/GTIN/registro.
- Criar adaptador `CatalogProvider` e `CatalogResult` com `source`, `observed_at`, licença, qualidade, registro e ID externo.
- Exigir confirmação humana da apresentação antes de usar em plano/estoque.

### Fase B — Prova de preços reais

- Selecionar 2–3 fontes candidatas (não pressupor que forneçam API) e contatá-las formalmente.
- Validar contrato, cobertura por CEP, atualização, preço de fidelidade, unidades e consultas por produto.
- Implementar apenas uma prova de integração **com fonte autorizada** e evidências reais (sem publicar credenciais).
- Testar pelo menos 20 apresentações representativas e 3 CEPs, ou amostra ajustada por disponibilidade, registrando taxa de correspondência e cobertura.

### Fase C — Comparação de ofertas

- Normalizar o produto em `commercial_presentation`; nunca comparar concentrações ou tamanhos de embalagem distintos como iguais.
- Manter `offer_snapshot` com fonte e instante.
- Calcular custo total quando frete/taxas forem conhecidos, separar programas de fidelidade e usar status de disponibilidade explícito.
- Exibir ``sem dados suficientes`` para comparação parcial; não declarar "mais barato" fora da amostra verificada.

### Fase D — Evolução

- Otimização de cesta entre lojas apenas após garantir frete e regras para múltiplos itens.
- Histórico de preços apenas com permissão/licença para retenção e redistribuição.
- Alertas de queda de preço somente se atualização periódica e custos forem viáveis.

## Contrato de adaptador (conceitual)

```python
class OffersProvider(Protocol):
    async def search(self, presentation_id: str, postal_code: str,
                     quantity: int, fulfillment: str) -> list[ProviderOffer]: ...
```

A implementação deve mapear para um modelo comum:

- `provider_id`, `retailer_id`, `external_product_id` e `matching_evidence`.
- `item_price`, `currency`, `freight`, `fees`, `conditional_discounts`, `quantity`.
- `stock_status` (available/unavailable/unknown) e `fulfillment`.
- `postal_code_area`, `observed_at`, `expires_at?`, `source_url?`, `license_id?`.
- `source_confidence`, `price_comparability`, `last_checked_at` e erros por fonte.

O catálogo de apresentação deve documentar também o tipo de embalagem e unidade de dispensação: sem isso, "preço por comprimido" pode ser uma comparação incorreta.

## Política de atualização

- Não fixar TTL universal antes de testar cada fonte; definir SLA/TTL por contrato e comportamento observado.
- Expirar snapshots que ultrapassem a validade do provedor ou política aprovada.
- Respeitar rate limits, timeout, cache, backoff, retries controlados e circuit breaker.
- Não persistir dados de saúde associados à pesquisa na infraestrutura do varejista além do necessário para consulta; evitar expor quem usa o medicamento.
- Capturar erros sem registrar medicamento + pessoa identificável em logs técnicos.

## Matriz de avaliação do integrador

| Critério | Evidência exigida | Passa? |
|---|---|---|
| Uso autorizado | Termos/contrato/licença | Pendente |
| Precisão do produto | Correspondência por apresentação | Pendente |
| Cobertura geográfica | CEPs testados | Pendente |
| Disponibilidade | Campo e recência verificáveis | Pendente |
| Preço final | Frete/desconto/impostos aplicáveis | Pendente |
| Atualização | SLA ou medida de frescor | Pendente |
| Links de compra | Destinos reais válidos | Pendente |
| Custo | Preço por consulta/limites | Pendente |
| Privacidade | Avaliação de dados transmitidos | Pendente |
| Resiliência | Comportamento sob indisponibilidade | Pendente |

## Saídas obrigatórias de uma POC

Relatório com fornecedor, data, termos, amostra, erros, taxa de match, preço de referência, condição de compra, cobertura, custo operacional e decisão `GO / NO-GO`. Se nenhuma fonte passar, a gestão de estoque e lista de compras permanecem funcionais, e a comparação deve aparecer como **não disponível**, não simulada.

## Fontes oficiais para pesquisa

- [Anvisa — Sistema de Consultas](https://www.gov.br/anvisa/pt-br/sistemas/sistema-de-consultas/)
- [Anvisa — preços de medicamentos CMED](https://www.gov.br/anvisa/pt-br/assuntos/medicamentos/cmed/precos/precos)

**Relações:** `04-regras-negocio.md`, `08-contratos-api.md`, `13-roadmap.md`.
