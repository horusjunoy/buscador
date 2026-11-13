# 04 — Regras de negócio e invariantes

**Versão:** 0.1 · **Status:** PROPOSTO — requer validação funcional e clínica de fluxos sensíveis.

## Glossário

- **Medicamento (conceito):** substância/princípio ativo ou formulação de referência, sem caracterizar uma embalagem comercial.
- **Apresentação:** concentração, forma farmacêutica, quantidade por embalagem, fabricante, GTIN e registro, quando conhecidos.
- **Plano de uso:** informação registrada de horários/quantidades para determinada pessoa, com fonte da orientação e período de validade; não equivale a prescrição emitida pelo app.
- **Ocorrência de dose:** instância de um plano em um instante previsto.
- **Ação de dose:** confirmação explícita ou alteração registrada por usuário/cuidador autorizado.
- **Lote doméstico:** quantidade identificável da mesma apresentação com vencimento/entrada.
- **Movimentação:** evento de entrada, consumo, ajuste, descarte ou reversão do estoque.
- **Oferta:** preço e condição coletados de fonte identificada em um momento, sem garantia posterior.

## RN-01 — Estados de dose

Estados de visualização: `pendente`, `adiada`, `tomada_confirmada`, `nao_tomada_informada`, `sem_confirmacao`, `cancelada_por_edicao`.

- `pendente` → `tomada_confirmada` apenas após ação humana autorizada.
- `pendente` → `nao_tomada_informada` apenas após declaração humana; não é inferida pelo relógio.
- `pendente` → `adiada`: reagenda um aviso, **sem consumo** e sem mudar posologia.
- `pendente` → `sem_confirmacao`: quando uma janela de registro expira; representa **ausência de informação**, não fato clínico.
- Uma ação posterior pode corrigir o registro por evento compensatório, sempre preservando o histórico.
- Se houver registro retrospectivo, manter `scheduled_at`, `recorded_at` e `taken_at` informado separadamente.
- Nunca recomendar dose dupla, compensar horários ou alterar tratamento.

## RN-02 — Consumo de estoque

- Apenas `tomada_confirmada` produz consumo automático, uma única vez, por ocorrência e versão de confirmação.
- Consumo = quantidade efetivamente registrada, convertida à unidade canônica da apresentação **somente com fator validado**.
- Se o saldo for insuficiente, não bloquear registro clínico do usuário: registrar divergência e sinalizar necessidade de conciliação, sem tornar estoque negativo silenciosamente.
- Toda alteração de saldo corresponde a `inventory_movement` imutável; saldo atual é derivado de movimentos confirmados.
- Ajustes manuais exigem motivo, ator, horário, lote e vínculo com movimento anterior quando aplicável.
- Não consumir lote vencido automaticamente. Para distribuição entre lotes aptos, usar FEFO (first-expiring-first-out) **como convenção contábil a validar**, não declaração de qual unidade física foi consumida.

## RN-03 — Projeções

- `estoque_real` = soma das entradas e saídas registradas; `estoque_projetado` = cenário calculado, nunca armazenado como verdade de inventário.
- `consumo_diario_planejado` deriva de doses planejadas e pode variar por dias/recorrência.
- Data projetada de ruptura = primeira data futura em que a soma acumulada de doses planejadas excede saldo apto; calendário real é preferível a média diária quando houver recorrências irregulares.
- Alerta de compra quando `data_projetada <= agora + lead_time + margem_seguranca` (valores configuráveis e explícitos).
- Vencimento antes do consumo reduz estoque apto estimado; não equivale a orientar descarte ou uso.
- Sem posologia suficiente, unidade conversível ou saldo confiável: mostrar previsão indeterminada e oferecer conciliação manual.
- Não criar compra automática; listar sugestão e aguardar decisão.

### Exemplo ilustrativo

10 comprimidos aptos, plano de 2 comprimidos/dia: cobertura de **5 dias** se todos os dias forem de consumo e não houver vencimento antes disso. A confirmação de 1 dose de 2 comprimidos gera movimentação de **−2**; apenas abrir o lembrete não altera o saldo.

## RN-04 — Comparação de preços

- Correspondência exata considera identificadores e, no mínimo, princípio ativo/nome do produto, concentração, forma e quantidade da embalagem; não deduzir equivalência terapêutica.
- Genéricos, similares ou apresentações alternativas podem aparecer em seção **separada e rotulada**, sem sugestão de substituição clínica ou troca automática.
- Preço final da cesta de uma farmácia = itens + taxas + frete conhecido − descontos efetivamente aplicáveis, com condições exibidas.
- Ordenar por menor **custo total comparável**, não apenas menor preço nominal, quando houver frete; se dados incompletos, declarar comparação parcial.
- Registrar `source`, `observed_at`, `expires_at` quando conhecido, `last_checked_at`, condições de fidelidade, CEP/região e disponibilidade (`disponivel`, `indisponivel`, `desconhecida`).
- Oferta expirada, sem estoque verificado ou sujeita a fidelidade deve ser sinalizada; não inventar valores nem links.
- CMED/PMC é referência regulatória de teto, **não oferta de farmácia**.

## RN-05 — Família e permissões

- Cada recurso sensível pertence a uma pessoa e a uma família/tenant; acesso exige vínculo ativo e permissão explícita.
- Permissões separadas: `view_medications`, `manage_stock`, `manage_plans`, `record_doses`, `manage_members`.
- Alteração de permissões tem trilha de auditoria; revogação bloqueia novos acessos imediatamente no backend e aciona revogação/limpeza de caches conforme estratégia offline.
- Informações de menores exigem desenho de responsável legal e privacidade apropriados; não presumir livre compartilhamento familiar.

## RN-06 — Offline e sincronização

- Comando offline recebe `client_event_id` UUID, `occurred_at`, `recorded_at`, versão do plano e contexto da pessoa.
- O backend deduplica `client_event_id` e `Idempotency-Key` e aplica efeitos em transação.
- Conflitos concorrentes ficam visíveis em processo de reconciliação; nunca descartar silenciosamente confirmação ou movimento.
- Alterações de plano futuras invalidam e reagendam ocorrências ainda não efetivadas; fatos passados preservados.
- Notificação não confirma dose, e push não é fonte de verdade.

## RN-07 — Auditoria e reversibilidade

- Eventos de negócio relevantes são append-only; correções geram reversões explícitas.
- Não registrar nomes de medicamentos ou informações clínicas identificáveis em logs de infraestrutura.
- Exclusão/retificação de dados sob LGPD será tratada conforme base legal, direitos e retenções justificadas, com plano documentado; append-only não significa retenção eterna.

## Pontos que requerem validação antes de implementação crítica

1. Política de janelas de ocorrência e status `sem_confirmacao`.
2. Regra de alocação automática de lote (FEFO ou escolha explícita).
3. Fracionamento e unidades (comprimido, meia unidade, gota, mL, aplicação).
4. Diferença entre plano informado, documento de prescrição e confirmação por cuidador.
5. Política de retroatividade de confirmações e ajustes.

**Relações:** `07-modelo-dados.md`, `08-contratos-api.md`, `11-testes.md`.
