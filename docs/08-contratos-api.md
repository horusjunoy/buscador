# 08 — Contratos de API (rascunho versionado)

**Versão:** 0.1 · **Status:** PROPOSTO, **não implementado** · **Base URL:** `/v1`

## Padrões de contrato

- REST/JSON UTF-8, HTTPS, timestamps ISO 8601 UTC, identificadores UUID.
- Autenticação: token de sessão; refresh/revogação definidos no desenho de identidade.
- Autorização por `household_id`, `person_id` e escopo — validação backend, sem confiar em claims isoladas do cliente.
- `Idempotency-Key` obrigatório para confirmações, correções, entradas/saídas e importações de movimentos.
- Paginação por cursor; `limit` com teto; filtros explícitos; rate limits e versionamento.
- Requisições reprovadas usam `application/problem+json` (RFC 9457) com códigos internos estáveis; detalhes sem vazamento de dados.
- `ETag`/`If-Match` ou `version` para atualizações sujeitas a concorrência.

## Endpoints inicialmente propostos

| Método | Caminho | Uso | Autorização |
|---|---|---|---|
| POST | `/auth/register` | Cadastro | Público com verificações |
| POST | `/auth/session` | Login | Público protegido por rate limit |
| POST | `/auth/refresh` | Renovar sessão | Sessão válida |
| POST | `/auth/logout` | Revogar sessão | Conta |
| GET/POST | `/households` | Listar/criar família | Conta |
| GET/POST | `/households/{id}/persons` | Pessoas | `manage_members` para mutação |
| GET/POST | `/households/{id}/memberships` | Convites/permissões | `manage_members` |
| GET | `/catalog/presentations` | Busca e filtros | Conta |
| POST | `/persons/{id}/medications` | Cadastrar manual/associar apresentação | `manage_plans` ou regra própria |
| GET/POST | `/households/{id}/stock-batches` | Estoque físico | `view_medications` / `manage_stock` |
| POST | `/stock-batches/{id}/movements` | Entrada/ajuste/descarte | `manage_stock`, idempotência |
| GET/POST | `/persons/{id}/plans` | Listar/criar planos | `view_medications` / `manage_plans` |
| PATCH | `/plans/{id}` | Nova versão do plano | `manage_plans`, concorrência |
| GET | `/persons/{id}/dose-occurrences` | Ocorrências por período | `view_medications` |
| POST | `/dose-occurrences/{id}/actions` | Tomada/não tomada/adiamento | `record_doses`, idempotência |
| POST | `/dose-actions/{id}/corrections` | Correção auditável | `record_doses` e política |
| GET | `/persons/{id}/replenishment` | Projeção explicável | `view_medications` |
| GET/POST | `/households/{id}/shopping-items` | Lista de compras | Escopo de compras |
| GET | `/offers` | Pesquisa de ofertas por apresentação/CEP | Escopo de compras; fonte verificada |
| POST | `/sync/commands` | Envio em lote de eventos offline | Autenticação + validação por comando |
| GET | `/privacy/export` | Solicitar exportação | Titular/responsável legitimado |
| POST | `/privacy/deletion-requests` | Solicitar exclusão | Titular/responsável legitimado |

Endpoint não implementado ou integrador não existente **não deve** responder com resultados falsos.

## Exemplo — ação de dose

```http
POST /v1/dose-occurrences/5e61b6d4-8e8e-4eea-baf7-4f0c5c6e5d34/actions
Authorization: Bearer <token>
Idempotency-Key: 3e152a2d-8c7c-47b9-a3fe-f876e1d1adcd
Content-Type: application/json
```

```json
{
  "client_event_id": "ccfce3f8-e4ac-45f8-8e4e-d6b5c896a1da",
  "action": "taken_confirmed",
  "recorded_at": "2026-11-12T22:00:00Z",
  "taken_at": "2026-11-12T21:58:00Z",
  "plan_version_id": "3d52ef7e-31a2-4ce4-baa0-b2f068789ab1"
}
```

Exemplo de resposta proposta — **dados sintéticos**:

```json
{
  "action_id": "da51ffad-9d93-4da3-a6aa-5d5173979db1",
  "occurrence_status": "taken_confirmed",
  "inventory_effect": "posted",
  "inventory_movement_id": "6d7989e2-90e8-42eb-9740-923b0a7cdcc7",
  "sync_state": "confirmed"
}
```

**Notas:** o cliente não envia uma quantidade de consumo arbitrária para a baixa automática; a quantidade vem da versão validada do plano e de eventual confirmação explícita de dose diferente, conforme regra aprovada. A política para estoque insuficiente pode produzir `inventory_effect: pending_reconciliation`.

## Exemplo — oferta verificada

```json
{
  "offer_id": "e0763489-94cb-41e9-9501-c96d9d27e918",
  "presentation_id": "642c3fbe-a01d-4582-8815-4c012bd97cd9",
  "retailer": { "id": "retailer-example", "name": "Farmácia Exemplo" },
  "currency": "BRL",
  "item_price": "39.90",
  "shipping_price": null,
  "total_comparable": null,
  "availability": "unknown",
  "conditions": ["Frete não informado"],
  "observed_at": "2026-11-12T20:00:00Z",
  "source_type": "authorized_partner",
  "source_reference": "EXEMPLO-SEM-FONTE-REAL",
  "purchase_url": null,
  "is_verified": false
}
```

Este JSON é **ilustrativo e não deve ser servido como oferta real**. Sem `is_verified: true` e prova de origem, não incluir no ranking de preços atuais.

## Erros padronizados

| HTTP | Código interno | Significado |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Entrada inválida |
| 401 | `UNAUTHENTICATED` | Sessão ausente/inválida |
| 403 | `FORBIDDEN_SCOPE` | Sem escopo para pessoa/família |
| 404 | `RESOURCE_NOT_FOUND` | Inexistente ou ocultado por isolamento |
| 409 | `STATE_CONFLICT` | Evento conflitante ou versão desatualizada |
| 422 | `BUSINESS_RULE_VIOLATION` | Regra de negócio não atendida |
| 429 | `RATE_LIMITED` | Limite de chamadas |
| 503 | `SOURCE_UNAVAILABLE` | Fonte externa indisponível, sem inventar dado |

## Gates de contrato

1. OpenAPI correspondente a implementações reais; contrato gerado e validado no CI.
2. Cada POST crítico tem teste de reenvio idempotente e ação concorrente.
3. Todo endpoint privado tem teste de acesso cruzado entre duas famílias.
4. Schema público não expõe registros clínicos por engano.
5. Alterações incompatíveis exigem versionamento e plano de migração do app.

**Relações:** `05-arquitetura.md`, `07-modelo-dados.md`, `11-testes.md`.
