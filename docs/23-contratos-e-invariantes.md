# 23 — Contratos comportamentais e invariantes de consistência

## Dose

1. Toda ocorrência tem `occurrence_id` estável, `treatment_version_id`, `person_id`, `scheduled_at_utc`, `local_timezone`, `local_date`, `status` e revisão (`version`).
2. Registrar `Tomei` exige confirmação explícita com `actor_id`, `occurred_at`, `recorded_at` e idempotency key. Pode ser registrada retrospectivamente com clareza, segundo política aprovada; não retroagir silenciosamente.
3. Registrar `Não tomei` é declaração explícita; desativa baixa automática. Ausência de confirmação = `sem_confirmacao`, não `nao_tomada_declarada`.
4. `Adiar` cria evento de lembrete (`remind_at`) sem alterar a prescrição/plano; não representa consumo. Política de limite e conflitos precisa ser registrada.
5. Confirmar duas vezes a mesma ocorrência com a mesma chave retorna mesmo resultado e não gera nova baixa. Confirmações conflitantes com outra chave recebem `409`/fluxo de conciliação.
6. Correções geram evento de reversão e novo evento vinculados, nunca exclusão destrutiva do histórico.

## Estoque

1. Saldo real = soma das entradas válidas − saídas confirmadas − descartes ± ajustes auditáveis. Projeção futura fica em agregados **separados**.
2. Movimentos possuem `movement_id`, `lot_id`, `quantity_decimal`, `unit`, `reason`, `actor_id`, `idempotency_key`, `created_at_utc`, `related_occurrence_id?`, `reverses_movement_id?`.
3. Quantidades e conversões têm precisão decimal explícita e tipo de unidade; proibir soma entre mL/comprimidos sem regra aprovada.
4. Baixa de dose é transação atômica vinculada ao registro da confirmação. Se não existir saldo correspondente, guardar confirmação da dose e registrar `stock_reconciliation_required` sem tornar saldo negativo. A política de abatimento por lote/FEFO aguarda decisão.
5. Confirmação de compra não movimenta estoque. Somente recebimento validado gera movimento de entrada.
6. Lote vencido deve ser destacado, nunca apresentado como disponível para consumo sem aviso; o aplicativo não decide conduta clínica.

## Sincronização e autenticação

1. Toda ação offline recebe ID global/local estável, idempotency key e timestamp do cliente. O servidor registra timestamp próprio, valida autoria, versão, perfil e limites.
2. Fila local persiste após fechamento/reinício de app, usa retry com backoff e não repete operação já confirmada; revogação de permissão impede sincronização não autorizada.
3. Com duas gravações simultâneas, serialização/lock transacional ou controle otimista impede dupla baixa. Conflitos aparecem ao usuário para resolução, sem descarte silencioso.
4. Guardar tokens com armazenamento seguro adequado a cada SO; não registrar payload clínico em logs genéricos/analytics.

## Preços e compras

1. Toda oferta deve conter: `source_id`, `source_terms_verified`, `retrieved_at`, `expires_at` ou TTL, `source_product_id`, `canonical_presentation_id`, `match_type`, `unit_price`, `currency`, `available_state`, `retail_channel`, `eligible_conditions`, `delivery_fee` quando verificável, `total_cost` quando todos componentes conhecidos e `source_url` validado.
2. Uma apresentação diferente, genérico ou referência não pode ser misturada silenciosamente com o produto solicitado. Identificar `exact_match` vs `alternative_requires_review`; nunca recomendar substituição terapêutica.
3. Se frete/benefício for desconhecido, mostrar **valor parcial**, não ordenar como `preço final` garantido. Filtro por retirada/entrega e CEP deve ser transparente.
4. Se fonte expirar, falhar ou não tiver cobertura, mostrar indisponibilidade/limitação. **Não usar resultados falsos de mock no ambiente produtivo.**
5. A lista de compras gera ação externa `Abrir na farmácia`, sem capturar pagamento e sem inferir compra/recebimento.

## Fuso e recorrência

- Armazenar instante UTC e fuso IANA; agendar conforme horário local planejado e política explícita para horário ambíguo/inexistente.
- Mudança de fuso, edição de plano e horário de verão precisam preservar versão do plano e eventos passados.
- O app deve apresentar a hora local da ocorrência e, quando apropriado, indicar fuso ativo.
