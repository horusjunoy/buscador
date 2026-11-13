# 25 — Dicionário de dados e objetos de domínio (referencial)

## Convenções

- PK de domínio: UUID/ULID, não sequencial exibido. Instantes em UTC; local timezone IANA; valores de dose/estoque como decimal com unidade explícita. IDs sempre associados ao escopo familiar e autorizados no servidor.
- `created_at`, `updated_at` para entidades mutáveis; eventos de auditoria append-only com `occurred_at`, `recorded_at`, `actor_id`, `source` e `idempotency_key`.
- PII e informações clínicas não devem ir para analytics genéricos. Dado de demo nunca entra como dado real.

| Entidade | Identificação, campos e relações essenciais | Invariante |
|---|---|---|
| `Account` | id, login_hash/identifier, auth_provider, status, locale, timezone | sessões revogáveis, confirmação contato |
| `Household` | id, owner_account_id, name | separação lógica e RBAC |
| `Person` | id, household_id, display_name, responsible_actor_id?, timezone | dados de saúde escopados por pessoa |
| `Membership` | id, household_id, account_id, role, status | convite e revogação auditáveis |
| `Delegation` | id, actor_id, person_id, permissions[], expiry | proibir acesso implícito entre pessoas |
| `Ingredient` | id, normalized_name, registry_source? | não implica substituição clínica |
| `MedicationPresentation` | id, name, ingredient_ids, strength, dosage_form, presentation_count, sale_unit, gtin?, registry_id? | identificadores completos, fonte |
| `OwnedMedication` | id, person_id?, household_id, presentation_id?, manual_snapshot | cadastro sem catálogo permitido |
| `StockLot` | id, household_id, owned_medication_id, lot_code?, expiry_date?, unit | saldo derivado do ledger |
| `StockMovement` | id, lot_id, qty_signed, unit, reason, related_occurrence_id?, reversal_of?, actor, idempotency_key | append-only, não duplicar nem negativo indevido |
| `TreatmentPlan` | id, person_id, medication_id, status, instructions_snapshot, active_version_id | autoria e versões preservadas |
| `TreatmentVersion` | id, plan_id, dose_qty, dose_unit, schedule_rule, timezone, start/end, supersedes? | nova versão não muda passado |
| `DoseOccurrence` | id, person_id, treatment_version_id, scheduled_at_utc, status, version | ocorrência única e rastreável |
| `DoseEvent` | id, occurrence_id, action, actor_id, occurred_at, recorded_at, idempotency_key | nunca inferir ingestão |
| `Reminder` | id, occurrence_id, remind_at, channel, delivery_state | alerta ≠ confirmação |
| `ReplenishmentProjection` | id, stock_snapshot_at, person_id?, medication_id, expected_end_date, assumptions | não altera estoque |
| `ShoppingItem` | id, household_id, presentation_id, requested_qty, unit, status | compra externa ≠ recebimento |
| `PharmacySource` | id, name, license_status, capabilities, terms_reviewed_at | nenhuma fonte inventada |
| `OfferSnapshot` | id, source_id, presentation_id, match_type, price, shipping?, total?, availability, retrieved_at, expires_at, source_url | oferta auditável e perecível |
| `AuditEvent` | id, actor_id, scope, action, resource_id, at, justification | sem conteúdo clínico em logs comuns |
| `SyncMutation` | id, actor_id, idempotency_key, client_event_id, received_at, status, response_digest | replay com mesmo resultado |

## Estados e enums propostos

- `DoseOccurrence.status`: `programada`, `pendente`, `adiada`, `tomada_confirmada`, `nao_tomada_declarada`, `sem_confirmacao`, `cancelada`.
- `StockMovement.reason`: `entrada_compra`, `entrada_ajuste`, `consumo_confirmado`, `saida_manual`, `descarte`, `reversao`, `ajuste_auditado`.
- `OfferSnapshot.availability`: `em_estoque`, `sem_estoque`, `desconhecido`.
- `OfferSnapshot.match_type`: `exata`, `alternativa_identificada`, `incerta` (não comparar incerta como idêntica).
- `ShoppingItem.status`: `pendente`, `oferta_aberta`, `recebimento_confirmado`, `cancelado`.

## Índices, constraints e fronteiras

- Unique para `(household_id, client_event_id)`/idempotency keys conforme escopo; unique de ocorrência programada por plano-versão+timestamp; check de unidades e quantidades; FKs de household/person com autorização explicitamente validada.
- Transações concorrentes de estoque devem fazer lock/controle de versão, e movimentos não podem ser editados destrutivamente.
- Retenção, criptografia, particionamento e exclusão são escolhas derivadas de política aprovada; **não inventar prazo legal**.
