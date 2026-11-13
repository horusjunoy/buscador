# 11 — Estratégia de testes e qualidade

**Versão:** 0.1 · **Status:** PROPOSTO · **Princípio:** qualidade precisa de evidência, não de declaração.

## Pirâmide de testes

1. **Unitários de domínio:** estados de dose, recorrência, conversão de unidades, estoque e projeções, independentes de rede/banco.
2. **Integração:** PostgreSQL real para constraints/transações, migrations e concorrência; integrações externas com mocks/fixtures sem fingir live.
3. **Contratos:** OpenAPI, validação de campos, compatibilidade, erros e autorização.
4. **Widget/mobile:** acessibilidade, estados, navegação, conteúdo e offline.
5. **Ponta a ponta:** jornada real em Android e iOS, incluindo notificações e queda de internet.
6. **Segurança/performance/recuperação:** IDOR/BOLA, dados expostos, stress, backup/restore e falhas por fonte.

## Matriz de cenários críticos

| ID | Cenário | Resultado esperado |
|---|---|---|
| T-001 | Usuário confirma dose uma vez | Uma ação, um movimento de consumo |
| T-002 | Retry da mesma confirmação 10x | Mesmo efeito da primeira solicitação |
| T-003 | Dois dispositivos confirmam simultaneamente | Sem baixa dupla; conflito auditável |
| T-004 | Usuário não responde lembrete | Sem confirmação, estoque inalterado |
| T-005 | Usuário declara não tomou | Sem consumo, histórico explícito |
| T-006 | Usuário adia lembrete | Novo horário de aviso sem alterar plano clínico ou estoque |
| T-007 | Corrigir uma dose tomada | Movimento compensatório, sem apagar evento original |
| T-008 | Sem internet na confirmação | Fila local; sincronização idempotente |
| T-009 | Reinstalação após evento pendente | Não duplicar efeito; indicar risco de perda local quando aplicável |
| T-010 | Alterar fuso e horário de verão | Ocorrências consistentes com política de fuso aprovada |
| T-011 | Vencimento anterior à próxima dose | Projeção sinaliza saldo apto reduzido, sem orientação clínica |
| T-012 | Lote com quantidade insuficiente | Registrar divergência sem saldo negativo oculto |
| T-013 | Produto sem quantidade por caixa | Não converter caixa em comprimidos |
| T-014 | Acesso a `person_id` de outra família | Bloqueio sem revelar dados |
| T-015 | Revogar autorização de cuidador | Novas consultas e comandos rejeitados |
| T-016 | Fonte de preço indisponível | Estado sem ofertas; sem valores inventados |
| T-017 | Oferta vencida/sem frete | Exibição de limite de comparação |
| T-018 | Duas apresentações distintas | Não mesclar indevidamente |
| T-019 | Notificação negada pelo SO | App continua útil e informa limitação |
| T-020 | Restore de backup em HML | Dados e integridade de eventos preservados |
| T-021 | App em fonte grande/leitor de tela | Fluxo principal permanece utilizável |
| T-022 | Log de erro em dose | Não vaza identificação médica |
| T-023 | Evento offline após revogação de acesso | Rejeição e tratamento seguro do conflito |
| T-024 | Atualização de plano após doses passadas | Histórico intacto, futuras atualizadas |

## Provas obrigatórias para alarmes

- Teste em Android e iOS reais, com permissão concedida/negada/revogada.
- Teste com app em primeiro plano, background e fechado, reinicialização e economias de bateria selecionadas.
- Teste de reschedule após editar plano, alterar fuso, atualizar sistema/app e restabelecer conectividade.
- Medir atraso observado e falhas; apresentar limitação ao usuário. Não prometer entrega garantida.

## Critérios de gate CI/CD

- Lint, formatação, tipagem e análise estática aprovados.
- Testes unitários de regras críticas sem falhas; cenário novo = teste novo.
- Migrações aplicadas/revertidas em ambiente temporário controlado (quando reversíveis).
- Scan de dependências, segredo e contêiner; falhas críticas bloqueiam promoção.
- Testes de contrato e autorização; nenhum recurso sensível com lacuna conhecida de IDOR.
- Relatório de execução com data, ambiente, versão e evidências reais.
- Cobertura de código acompanhada por módulo, sem usar número global como substituto de qualidade.

## Plano de homologação

1. Seed sintético, sem dados de usuários reais.
2. Execução das jornadas J01–J06 em HML.
3. Confrontar estoque derivado dos eventos com saldo esperado manualmente.
4. Verificar resultados de POC de preços com fontes reais documentadas.
5. Executar checklist de acessibilidade e privacidade.
6. Registrar aceite por requisito; defeitos bloqueantes impedem publicação.

## Definição de pronto (DoD)

Código revisado, testes executados com evidência, API/modelo/documentação atualizados, migração e rollback planejados, observabilidade sem vazamento, fluxos de erro/carga/offline cobertos e status atualizado em `15-status-projeto.md`.

**Relações:** `02-prd.md`, `03-jornadas.md`, `04-regras-negocio.md`, `12-infraestrutura.md`.
