# 16 — Backlog completo de épicos (Buscador e Gestor de Medicamentos)

**Versão:** 0.2.0 · **Data:** 12/11/2026 · **Status:** PROPOSTO / NÃO APROVADO

> Este documento descreve **escopo planejado**, não funcionalidade implementada. Está alinhado aos documentos 01–15, mas não substitui PRD, regras, ADRs ou testes. Todos os preços, disponibilidade e integrações com farmácias são **condicionais a fontes reais autorizadas**.

## 1. Premissas de planejamento

- **Foco:** medicamento correto → plano informado → lembrete → confirmação → saldo físico → previsão de falta → comparação de ofertas → compra externa → entrada confirmada no estoque.
- **MVP núcleo:** usar e controlar estoque/agenda de modo confiável **mesmo sem provedores de preço**.
- **Trilha de preços em paralelo:** pesquisa/POC inicia cedo; conectores e comparador só após `GO` técnico, jurídico e comercial. `NO-GO` não bloqueia o MVP núcleo.
- **Não prescrever:** nenhum algoritmo pode recomendar alteração de dose, compensação, equivalência terapêutica ou substituição medicamentosa.
- **Estados:** *pendente* ou *sem confirmação* não significa *não tomada*; *adiar lembrete* não significa *alterar orientação clínica*.
- **Saldo:** estoque físico muda somente após evento confirmado; projeções ficam separadas e têm premissas explícitas.
- **Segurança:** dados de saúde são sensíveis, com autorização por pessoa/família, auditoria e minimização.

## 2. Legenda

| Campo | Significado |
|---|---|
| `P0` | Necessário para o núcleo utilizável e/ou para controle de risco; `P0 pesquisa` = descoberta indispensável, não compromisso de integração |
| `P1` | Evolução condicional ou melhoria importante; não bloqueia o núcleo do MVP |
| `P2` | Pós-MVP, sujeito a descoberta e custo-benefício |
| `Núcleo` | Entrega necessária para piloto funcional e confiável |
| `Condicional` | Depende de fornecedor/licença/POC autorizada, não deve ser apresentada como pronta |
| `Evolução` | Pode ser executado após o fluxo manual confiável |
| `Futuro` | Escopo potencial da V2; não comprometido com lançamento |
| `E0–E8` | Etapas da sequência proposta em `13-roadmap.md`; não equivalem a semanas |

## 3. Visão geral dos épicos

| ID | Épico | Frente | Prioridade | Etapa | Escopo | Dependências |
|---|---|---|---|---|---|---|
| EP-001 | Visão, escopo e governança do produto | Produto | P0 | E0 | Núcleo | — |
| EP-002 | Pesquisa UX, arquitetura de informação e jornadas | Experiência | P0 | E0–E1 | Núcleo | EP-001 |
| EP-003 | Design System, UI e acessibilidade | Experiência | P0 | E0–E1 | Núcleo | EP-001, EP-002 |
| EP-004 | Arquitetura modular, banco, API e fundação do código | Plataforma | P0 | E1 | Núcleo | EP-001 |
| EP-005 | Cadastro, login, recuperação e sessões | Contas e família | P0 | E1 | Núcleo | EP-004, EP-025 |
| EP-006 | Famílias, membros, responsáveis e cuidadores | Contas e família | P0 | E1–E2 | Núcleo | EP-005, EP-025 |
| EP-007 | Catálogo, nomenclatura e apresentação comercial | Medicamentos e estoque | P0 | E2 | Núcleo | EP-004 |
| EP-008 | Cadastro assistido, código de barras e correção de cadastro | Medicamentos e estoque | P1 | E2 / V1 | Evolução | EP-007, EP-020 |
| EP-009 | Inventário doméstico, unidades, lotes e locais | Medicamentos e estoque | P0 | E2 | Núcleo | EP-006, EP-007 |
| EP-010 | Movimentações, conciliação e rastreabilidade de estoque | Medicamentos e estoque | P0 | E2–E3 | Núcleo | EP-009, EP-025 |
| EP-011 | Validade, lote vencido e descarte seguro | Medicamentos e estoque | P0 | E5 | Núcleo | EP-009, EP-010 |
| EP-012 | Registro de prescrição e planos de tratamento | Tratamentos e doses | P0 | E3 | Núcleo | EP-006, EP-007, EP-025 |
| EP-013 | Motor de agenda e geração de ocorrências de dose | Tratamentos e doses | P0 | E3 | Núcleo | EP-012 |
| EP-014 | Confirmação de dose, adiamento, não tomada e histórico | Tratamentos e doses | P0 | E3 | Núcleo | EP-010, EP-013 |
| EP-015 | Lembretes e notificações confiáveis | Tratamentos e doses | P0 | E4 | Núcleo | EP-013, EP-014, EP-016 |
| EP-016 | Operação offline, fila de eventos e sincronização | Tratamentos e doses | P0 | E4 | Núcleo | EP-010, EP-013, EP-014, EP-025 |
| EP-017 | Painel Hoje, busca interna e visão familiar | Tratamentos e doses | P0 | E3–E5 | Núcleo | EP-009, EP-013, EP-014, EP-016 |
| EP-018 | Projeção de consumo e previsão de término | Reposição | P0 | E5 | Núcleo | EP-009, EP-010, EP-011, EP-012, EP-013 |
| EP-019 | Alertas de reposição e lista de compras | Reposição | P0 | E5 | Núcleo | EP-018, EP-009 |
| EP-020 | Integração e proveniência de catálogo externo | Mercado e preços | P1 | E2 / POC | Condicional | EP-007 |
| EP-021 | Viabilidade comercial e técnica de preços reais | Mercado e preços | P0 pesquisa | POC-P paralela | Condicional | EP-001, EP-007 |
| EP-022 | Conectores de ofertas de farmácias | Mercado e preços | P1 | E6 | Condicional | EP-021, EP-007, EP-025 |
| EP-023 | Busca, correspondência e comparação de ofertas | Mercado e preços | P1 | E6 | Condicional | EP-022, EP-007 |
| EP-024 | Acesso à farmácia e conclusão administrativa da reposição | Mercado e preços | P1 | E6 | Condicional | EP-019, EP-023, EP-009 |
| EP-025 | Privacidade, LGPD, segurança e trilha de acesso | Transversal | P0 | E0–E8 | Núcleo | EP-001 |
| EP-026 | Qualidade, testes automatizados e validação funcional | Transversal | P0 | E1–E8 | Núcleo | EP-004, EP-025 |
| EP-027 | DevOps, observabilidade, backups e operação | Transversal | P0 | E1–E8 | Núcleo | EP-004, EP-025, EP-026 |
| EP-028 | Piloto, feedback, suporte e publicação Android/iOS | Lançamento | P0 | E7–E8 | Núcleo | EP-001, EP-025, EP-026, EP-027, EP-015 |
| EP-029 | OCR e importação assistida de prescrições/embalagens | Pós-MVP | P2 | V2 | Futuro | EP-007, EP-012, EP-025 |
| EP-030 | Otimização de cesta, histórico e alertas de preços | Pós-MVP | P2 | V2 | Futuro | EP-022, EP-023, EP-024 |
| EP-031 | Relatórios familiares, cuidadores e portabilidade | Pós-MVP | P2 | V2 | Futuro | EP-006, EP-014, EP-025 |
| EP-032 | Assistente conversacional e automações assistidas | Pós-MVP | P2 | V2 | Futuro | EP-017, EP-019, EP-025, EP-026 |

## 4. Épicos detalhados

As histórias abaixo são **candidatas**. Cada história precisa ser refinada em tarefas, contratos, telas, migrações e testes antes de entrar em desenvolvimento. A numeração `US-XXX.YY` é provisória e rastreável.

### EP-001 — Visão, escopo e governança do produto

**Frente:** Produto · **Etapa:** E0 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Transformar a visão em decisões, prioridades, indicadores e um backlog controlável.

**Histórias candidatas:**

- `US-001.01` — Validar público inicial, jornadas e problemas mais frequentes.
- `US-001.02` — Definir escopo do MVP, exclusões e métricas observáveis.
- `US-001.03` — Criar histórias com DoR, critérios Given/When/Then e dependências.
- `US-001.04` — Registrar decisões (ADRs), riscos, mudanças e definição de pronto.

**Critérios de aceite do épico:**

- [ ] PRD e prioridades revisados, com pressupostos identificados.
- [ ] Toda história P0 possui ator, valor, regra e evidência de aceite.
- [ ] Mudanças em escopo, custo ou segurança são aprovadas antes da execução.

**Dependências:** Nenhuma dependência de implementação.

**Risco/limite:** Documentar não é evidência de construção; não presumir resultado de pesquisa com usuários.

---

### EP-002 — Pesquisa UX, arquitetura de informação e jornadas

**Frente:** Experiência · **Etapa:** E0–E1 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Oferecer fluxo simples para quem usa, organiza ou acompanha medicamentos.

**Histórias candidatas:**

- `US-002.01` — Mapear personas e jornadas de primeiro acesso, dose, estoque e compra.
- `US-002.02` — Projetar navegação: Hoje, Medicamentos, Estoque, Comprar, Família e Configurações.
- `US-002.03` — Prototipar estados de vazio, erro, offline e dose atrasada.
- `US-002.04` — Validar fluxos com usuários representativos, inclusive idosos.

**Critérios de aceite do épico:**

- [ ] Caminho cadastrar → agendar → confirmar → verificar estoque demonstrável no protótipo.
- [ ] Cada jornada possui casos de falha e recuperação.
- [ ] Dificuldades de usabilidade registradas e priorizadas.

**Dependências:** EP-001.

**Risco/limite:** Não introduzir telas que exijam conhecimento farmacêutico desnecessário.

---

### EP-003 — Design System, UI e acessibilidade

**Frente:** Experiência · **Etapa:** E0–E1 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Manter padrões visuais e interações consistentes em Android e iOS.

**Histórias candidatas:**

- `US-003.01` — Definir tokens de cor, tipografia, espaçamento, elevação e ícones.
- `US-003.02` — Criar componentes de medicamento, dose, estoque, oferta, formulário e alerta.
- `US-003.03` — Padronizar estados: pendente, confirmada, declarada não tomada, adiada, cancelada.
- `US-003.04` — Preparar tamanhos de texto, contraste, leitor de tela e controles grandes.

**Critérios de aceite do épico:**

- [ ] Componentes reutilizáveis documentados e usados nas primeiras telas.
- [ ] Estados clínicos reconhecíveis sem depender apenas de cor.
- [ ] Fluxos críticos testados com fonte ampliada e leitor de tela.

**Dependências:** EP-001, EP-002.

**Risco/limite:** Design System é sistema de decisões; não validar apenas por aparência.

---

### EP-004 — Arquitetura modular, banco, API e fundação do código

**Frente:** Plataforma · **Etapa:** E1 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Criar uma base que permita evoluir cada domínio sem quebrar regras de dose e estoque.

**Histórias candidatas:**

- `US-004.01` — Criar monorepo ou estrutura de repositórios aprovada, módulos e dependências.
- `US-004.02` — Subir Flutter, FastAPI, PostgreSQL e Docker em ambiente DEV.
- `US-004.03` — Versionar migrações, contratos OpenAPI, erros e validações.
- `US-004.04` — Implantar padrões de idempotência, UTC/fuso IANA e transações críticas.

**Critérios de aceite do épico:**

- [ ] Build mobile e API executam com configurações documentadas.
- [ ] Migração inicial pode ser aplicada e revertida em ambiente de teste.
- [ ] Contratos versionados e testes de autorização dos endpoints base passam.

**Dependências:** EP-001.

**Risco/limite:** Preferir monólito modular no MVP; proibir acoplamento de regra clínica ao widget ou framework.

---

### EP-005 — Cadastro, login, recuperação e sessões

**Frente:** Contas e família · **Etapa:** E1 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Permitir acesso seguro e recuperar a conta sem exposição de dados de saúde.

**Histórias candidatas:**

- `US-005.01` — Criar conta, verificar contato e iniciar/encerrar sessão.
- `US-005.02` — Recuperar acesso, encerrar outras sessões e administrar dispositivos.
- `US-005.03` — Implementar token/sessão, limites de tentativa e renovação segura.
- `US-005.04` — Configurar preferências mínimas de idioma, fuso e notificações.

**Critérios de aceite do épico:**

- [ ] Usuário não autenticado não acessa dados privados.
- [ ] Recuperação não revela existência da conta nem expõe dados sensíveis.
- [ ] Sessões revogadas deixam de autorizar novas operações.

**Dependências:** EP-004, EP-025.

**Risco/limite:** Escolha do provedor de identidade e método de verificação depende de decisão técnica.

---

### EP-006 — Famílias, membros, responsáveis e cuidadores

**Frente:** Contas e família · **Etapa:** E1–E2 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Gerenciar medicamentos de múltiplas pessoas sem compartilhar permissões indiscriminadamente.

**Histórias candidatas:**

- `US-006.01` — Criar família e perfis de pessoas vinculadas.
- `US-006.02` — Convidar e revogar responsável/cuidador por pessoa e ação.
- `US-006.03` — Controlar papéis: visualizar, registrar dose, gerenciar estoque, editar plano.
- `US-006.04` — Implementar acesso e tratamento especial para menores.

**Critérios de aceite do épico:**

- [ ] Acesso a um familiar não concede acesso a outros.
- [ ] Revogar cuidador bloqueia novos acessos e preserva trilha de auditoria.
- [ ] Alterar dose, plano e estoque exige permissão apropriada.

**Dependências:** EP-005, EP-025.

**Risco/limite:** Responsabilidade legal e consentimentos de menores precisam de validação jurídica/funcional.

---

### EP-007 — Catálogo, nomenclatura e apresentação comercial

**Frente:** Medicamentos e estoque · **Etapa:** E2 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Identificar com precisão o medicamento e a apresentação utilizada.

**Histórias candidatas:**

- `US-007.01` — Modelar princípio ativo, nome, concentração, forma, embalagem e unidade.
- `US-007.02` — Distinguir medicamento, apresentação, item doméstico e plano de tratamento.
- `US-007.03` — Buscar por nome e reconhecer produtos com nomes semelhantes.
- `US-007.04` — Mostrar origem e confiança de registros externos, com confirmação humana.

**Critérios de aceite do épico:**

- [ ] Concentrações e embalagens diferentes não são tratadas como oferta idêntica.
- [ ] Cadastro doméstico é possível sem catálogo externo.
- [ ] Produto sem confirmação de apresentação não alimenta comparação automática.

**Dependências:** EP-004.

**Risco/limite:** Não inferir equivalência terapêutica apenas de princípio ativo/descrição.

---

### EP-008 — Cadastro assistido, código de barras e correção de cadastro

**Frente:** Medicamentos e estoque · **Etapa:** E2 / V1 · **Prioridade:** P1 · **Escopo:** Evolução · **Estado:** Proposto

**Resultado esperado:** Reduzir digitação sem comprometer identidade do medicamento.

**Histórias candidatas:**

- `US-008.01` — Cadastrar manualmente por busca/formulário e revisar dados.
- `US-008.02` — Ler GTIN/código de barras com câmera, quando autorizado.
- `US-008.03` — Resolver código não encontrado, embalagem alterada e produto ambíguo.
- `US-008.04` — Corrigir ou desativar cadastro preservando referência histórica.

**Critérios de aceite do épico:**

- [ ] Leitura não encontrada oferece cadastro manual.
- [ ] Código de barras não confirma automaticamente dose/concentração sem fonte confiável.
- [ ] Correções não apagam histórico de uso ou movimentação.

**Dependências:** EP-007, EP-020.

**Risco/limite:** Leitura por câmera só traz valor com cobertura de correspondência validada; cadastro manual é P0 em EP-007/009.

---

### EP-009 — Inventário doméstico, unidades, lotes e locais

**Frente:** Medicamentos e estoque · **Etapa:** E2 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Saber o que existe fisicamente em casa e a quem está disponível.

**Histórias candidatas:**

- `US-009.01` — Criar item doméstico por apresentação e local de armazenamento.
- `US-009.02` — Registrar unidades: comprimidos, cápsulas, mL, doses, frascos e outras.
- `US-009.03` — Controlar quantidades por lote, validade e embalagem aberta.
- `US-009.04` — Associar estoque individual ou compartilhado com regras explícitas.

**Critérios de aceite do épico:**

- [ ] Quantidade física é sempre explícita e auditável.
- [ ] Unidades incompatíveis não são somadas sem conversão documentada.
- [ ] Estoque compartilhado não implica acesso irrestrito a prescrições.

**Dependências:** EP-006, EP-007.

**Risco/limite:** Decidir política para fracionamento, embalagem aberta e líquidos antes de produção.

---

### EP-010 — Movimentações, conciliação e rastreabilidade de estoque

**Frente:** Medicamentos e estoque · **Etapa:** E2–E3 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Garantir saldo reconstituível e sem baixa duplicada.

**Histórias candidatas:**

- `US-010.01` — Registrar entrada, consumo confirmado, ajuste, descarte e estorno.
- `US-010.02` — Executar baixa de dose e movimento em transação única/idempotente.
- `US-010.03` — Criar trilha append-only e explicar diferença entre saldo e projeção.
- `US-010.04` — Resolver correção de erro com estorno e novo evento, não edição silenciosa.

**Critérios de aceite do épico:**

- [ ] Reprocessar a mesma confirmação não cria segunda baixa.
- [ ] Saldo pode ser reconstituído a partir das movimentações.
- [ ] Erro de estoque tem correção auditável e autor identificado.

**Dependências:** EP-009, EP-025.

**Risco/limite:** Eventos offline duplicados e baixa de dois familiares no mesmo lote exigem testes de concorrência.

---

### EP-011 — Validade, lote vencido e descarte seguro

**Frente:** Medicamentos e estoque · **Etapa:** E5 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Evitar que itens vencidos sejam considerados disponíveis para uso e compras.

**Histórias candidatas:**

- `US-011.01` — Alertar por faixa configurável de dias até vencimento.
- `US-011.02` — Separar saldo físico de saldo elegível para projeção.
- `US-011.03` — Registrar descarte, motivo e ajuste de quantidade.
- `US-011.04` — Exibir orientação administrativa de descarte sem recomendação clínica.

**Critérios de aceite do épico:**

- [ ] Lote vencido não participa do saldo utilizável para projeção.
- [ ] Alerta menciona qual lote, quantidade e data.
- [ ] Descarte gera movimentação auditável.

**Dependências:** EP-009, EP-010.

**Risco/limite:** Não recomendar automaticamente uso de lote vencido nem alteração de tratamento.

---

### EP-012 — Registro de prescrição e planos de tratamento

**Frente:** Tratamentos e doses · **Etapa:** E3 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Representar fielmente o plano informado para cada pessoa.

**Histórias candidatas:**

- `US-012.01` — Cadastrar posologia informada, origem, frequência, início e fim.
- `US-012.02` — Suportar tratamento contínuo, temporário e horários específicos.
- `US-012.03` — Versionar mudanças e preservar calendário/histórico anterior.
- `US-012.04` — Associar apresentação ao plano e registrar observações de uso declaradas.

**Critérios de aceite do épico:**

- [ ] Alterar plano não reescreve doses já registradas.
- [ ] Plano só é habilitado após confirmação explícita de parâmetros.
- [ ] Sistema não prescreve nem propõe dose ou compensação.

**Dependências:** EP-006, EP-007, EP-025.

**Risco/limite:** Doses condicionais/sob demanda e unidades fracionadas requerem regras específicas; não improvisar.

---

### EP-013 — Motor de agenda e geração de ocorrências de dose

**Frente:** Tratamentos e doses · **Etapa:** E3 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Gerar a linha do tempo correta das doses conforme o plano cadastrado.

**Histórias candidatas:**

- `US-013.01` — Gerar ocorrências identificáveis e reprodutíveis por versão do plano.
- `US-013.02` — Tratar fuso IANA, mudança de horário, viagem e horários locais.
- `US-013.03` — Representar pendente, vencimento da janela e cancelamento.
- `US-013.04` — Reconciliar mudanças sem duplicar ocorrências.

**Critérios de aceite do épico:**

- [ ] Cada ocorrência tem ID estável e vínculo com versão do plano.
- [ ] Mudanças de fuso não criam tomadas falsas nem doses duplicadas.
- [ ] Doses sem confirmação permanecem sem confirmação.

**Dependências:** EP-012.

**Risco/limite:** Expiração de janela não equivale automaticamente a “não tomou”.

---

### EP-014 — Confirmação de dose, adiamento, não tomada e histórico

**Frente:** Tratamentos e doses · **Etapa:** E3 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Registrar o que realmente aconteceu, com ator e momento.

**Histórias candidatas:**

- `US-014.01` — Confirmar “Tomei” com timestamp e ator autorizado.
- `US-014.02` — Registrar “Não tomei” como declaração explícita.
- `US-014.03` — Adiar lembrete mantendo vínculo com a ocorrência original.
- `US-014.04` — Exibir histórico, correção e estorno com trilha de auditoria.

**Critérios de aceite do épico:**

- [ ] Nenhuma dose passa a “tomada” sem confirmação.
- [ ] Confirmar duas vezes produz um único registro efetivo.
- [ ] Correção de tomada sincroniza estorno de estoque sem perder histórico.

**Dependências:** EP-010, EP-013.

**Risco/limite:** Adiar lembrete não deve ser interpretado como prescrição de novo horário de uso.

---

### EP-015 — Lembretes e notificações confiáveis

**Frente:** Tratamentos e doses · **Etapa:** E4 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Avisar no horário adequado e proporcionar ação clara ao usuário.

**Histórias candidatas:**

- `US-015.01` — Agendar notificações locais com permissões explícitas.
- `US-015.02` — Mostrar dose, pessoa e horários respeitando privacidade da tela bloqueada.
- `US-015.03` — Abrir dose correspondente e permitir confirmar ou adiar.
- `US-015.04` — Testar reinicialização, economia de bateria, atualização de app e fuso.

**Critérios de aceite do épico:**

- [ ] Permissões negadas geram instrução de recuperação visível.
- [ ] Histórico separa “notificação agendada”, “entrega desconhecida” e “dose confirmada”.
- [ ] Testes em aparelhos reais documentam limitações do Android/iOS.

**Dependências:** EP-013, EP-014, EP-016.

**Risco/limite:** Não prometer entrega garantida em qualquer circunstância nem usar push como única via.

---

### EP-016 — Operação offline, fila de eventos e sincronização

**Frente:** Tratamentos e doses · **Etapa:** E4 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Manter acesso e registro essenciais quando não houver internet.

**Histórias candidatas:**

- `US-016.01` — Disponibilizar agenda/estoque em cache com marcador de atualização.
- `US-016.02` — Persistir confirmações locais com IDs de evento e fila durável.
- `US-016.03` — Sincronizar de modo idempotente e tratar conflito multi-dispositivo.
- `US-016.04` — Sinalizar pendências e divergências sem perder ações.

**Critérios de aceite do épico:**

- [ ] Confirmação feita sem internet persiste após reiniciar o aplicativo.
- [ ] Reenvio da fila não duplica dose nem movimento de estoque.
- [ ] Conflito é reconciliado com política documentada e exibido quando necessário.

**Dependências:** EP-010, EP-013, EP-014, EP-025.

**Risco/limite:** Cache local com dados sensíveis precisa de proteção adequada; saldo offline pode estar desatualizado.

---

### EP-017 — Painel Hoje, busca interna e visão familiar

**Frente:** Tratamentos e doses · **Etapa:** E3–E5 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Entregar informação operacional clara em uma tela diária.

**Histórias candidatas:**

- `US-017.01` — Mostrar doses do dia por pessoa, horário e estado.
- `US-017.02` — Visualizar estoque disponível, vencimentos e próximos reabastecimentos.
- `US-017.03` — Pesquisar medicamentos cadastrados e filtrar por pessoa.
- `US-017.04` — Exibir falta de conexão, última sincronização e erros de forma compreensível.

**Critérios de aceite do épico:**

- [ ] Doses do dia exibidas vêm do mesmo motor de ocorrências.
- [ ] Itens urgentes são identificados por texto e acessibilidade.
- [ ] Painel não omite indisponibilidade ou incerteza de sincronização.

**Dependências:** EP-009, EP-013, EP-014, EP-016.

**Risco/limite:** Um painel agregador não deve calcular saldos por lógica duplicada no cliente.

---

### EP-018 — Projeção de consumo e previsão de término

**Frente:** Reposição · **Etapa:** E5 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Antecipar a falta de estoque usando planos ativos e estoque utilizável.

**Histórias candidatas:**

- `US-018.01` — Calcular demanda futura a partir de planos ativos e agendas.
- `US-018.02` — Aplicar saldo elegível, lotes, múltiplos usuários e unidades.
- `US-018.03` — Exibir previsão, premissas e nível de confiança.
- `US-018.04` — Recalcular após confirmação, ajuste, mudança do plano e entrada de compra.

**Critérios de aceite do épico:**

- [ ] Projeções são reprodutíveis e não movimentam estoque físico.
- [ ] Falta de informação exibe “previsão indisponível”, não data inventada.
- [ ] Testes cobrem tratamentos contínuos, temporários e estoque compartilhado.

**Dependências:** EP-009, EP-010, EP-011, EP-012, EP-013.

**Risco/limite:** Planos sob demanda ou não regulares têm previsões limitadas e explicitadas.

---

### EP-019 — Alertas de reposição e lista de compras

**Frente:** Reposição · **Etapa:** E5 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Transformar previsão em ação de compra organizada.

**Histórias candidatas:**

- `US-019.01` — Criar aviso por dias restantes, quantidade mínima e margem configurável.
- `US-019.02` — Adicionar e remover itens da lista de compras sem duplicações.
- `US-019.03` — Mostrar quantidade desejada, apresentação e pessoa/estoque de destino.
- `US-019.04` — Registrar compra recebida como entrada de estoque após confirmação.

**Critérios de aceite do épico:**

- [ ] Alerta ocorre antes da data prevista segundo parâmetro configurado.
- [ ] Adicionar à lista não simula compra nem aumenta estoque.
- [ ] Marcar “comprado” sem recebimento não altera estoque físico.

**Dependências:** EP-018, EP-009.

**Risco/limite:** Não disparar compras automáticas; ação financeira sempre requer decisão do usuário.

---

### EP-020 — Integração e proveniência de catálogo externo

**Frente:** Mercado e preços · **Etapa:** E2 / POC · **Prioridade:** P1 · **Escopo:** Condicional · **Estado:** Proposto

**Resultado esperado:** Ampliar identificação de apresentações com dados verificáveis.

**Histórias candidatas:**

- `US-020.01` — Mapear fontes de dados por nome, GTIN e registro, e respectivas licenças.
- `US-020.02` — Criar contrato CatalogProvider e normalização de apresentações.
- `US-020.03` — Guardar origem, timestamp, ID externo e evidência de correspondência.
- `US-020.04` — Medir cobertura, ambiguidades e desempenho em amostra real.

**Critérios de aceite do épico:**

- [ ] Fornecedor externo só opera após validação de direito de uso.
- [ ] Busca falha sem impedir cadastro manual.
- [ ] A apresentação encontrada exige confirmação em situações ambíguas.

**Dependências:** EP-007.

**Risco/limite:** Catálogo oficial acessível ao público não significa API autorizada ou uso sem licença.

---

### EP-021 — Viabilidade comercial e técnica de preços reais

**Frente:** Mercado e preços · **Etapa:** POC-P paralela · **Prioridade:** P0 pesquisa · **Escopo:** Condicional · **Estado:** Proposto

**Resultado esperado:** Decidir com evidência se o comparador pode oferecer preços reais no lançamento.

**Histórias candidatas:**

- `US-021.01` — Inventariar provedores/rede e verificar permissão, termos e custos.
- `US-021.02` — Testar correspondência de apresentações, CEP e disponibilidade.
- `US-021.03` — Comparar preço com frete, desconto e recência por fonte.
- `US-021.04` — Publicar parecer GO/NO-GO e contingência sem comparador.

**Critérios de aceite do épico:**

- [ ] Matriz com ao menos as dimensões: licença, cobertura, custo, match e frescor.
- [ ] Amostra e resultados são reproduzíveis, com provas e data.
- [ ] Nenhuma fonte é divulgada como integrada antes de contrato e testes.

**Dependências:** EP-001, EP-007.

**Risco/limite:** O comparador fica bloqueado em NO-GO; gestão de medicamentos e estoque continua funcionando.

---

### EP-022 — Conectores de ofertas de farmácias

**Frente:** Mercado e preços · **Etapa:** E6 · **Prioridade:** P1 · **Escopo:** Condicional · **Estado:** Proposto

**Resultado esperado:** Consumir ofertas autorizadas com comportamento consistente e resiliente.

**Histórias candidatas:**

- `US-022.01` — Implementar interface OffersProvider para primeira fonte aprovada.
- `US-022.02` — Normalizar preço, frete, desconto, disponibilidade e retirada/entrega.
- `US-022.03` — Tratar timeouts, indisponibilidade, rate limits, cache e política de expiração.
- `US-022.04` — Registrar rastreabilidade, consentimento e escopo de dados transmitidos.

**Critérios de aceite do épico:**

- [ ] Cada oferta mostra fonte, momento da consulta e alcance geográfico.
- [ ] Conector não afirma disponibilidade quando fonte é inconclusiva.
- [ ] Queda de provedor não derruba agenda, estoque ou lista de compras.

**Dependências:** EP-021, EP-007, EP-025.

**Risco/limite:** Integração só sai de MOCK em ambiente isolado após prova com fonte real autorizada.

---

### EP-023 — Busca, correspondência e comparação de ofertas

**Frente:** Mercado e preços · **Etapa:** E6 · **Prioridade:** P1 · **Escopo:** Condicional · **Estado:** Proposto

**Resultado esperado:** Ajudar a escolher opção mais econômica dentro de condições verificadas.

**Histórias candidatas:**

- `US-023.01` — Pesquisar apresentação exata e separar similares não equivalentes.
- `US-023.02` — Rankear ofertas comparáveis por custo final conhecido.
- `US-023.03` — Mostrar condições de fidelidade, frete, entrega, retirada e estoque.
- `US-023.04` — Mostrar cobertura parcial, fonte e data, e permitir filtros por CEP.

**Critérios de aceite do épico:**

- [ ] “Mais barato” é afirmado apenas entre ofertas comparáveis verificadas.
- [ ] Produtos com embalagem/concentração distinta não entram no mesmo ranking.
- [ ] Ofertas desatualizadas e preço final desconhecido são sinalizados.

**Dependências:** EP-022, EP-007.

**Risco/limite:** Não inferir substituição clínica nem garantir preço até fechamento da compra.

---

### EP-024 — Acesso à farmácia e conclusão administrativa da reposição

**Frente:** Mercado e preços · **Etapa:** E6 · **Prioridade:** P1 · **Escopo:** Condicional · **Estado:** Proposto

**Resultado esperado:** Permitir que o usuário prossiga para a compra e depois atualize o estoque.

**Histórias candidatas:**

- `US-024.01` — Abrir URL da oferta autorizada preservando apresentação e contexto.
- `US-024.02` — Informar que preço e disponibilidade podem mudar no checkout.
- `US-024.03` — Registrar na lista o estado “pedido/compra relatada/recebido”.
- `US-024.04` — Dar entrada no estoque apenas após recebimento confirmado e lote/quantidade.

**Critérios de aceite do épico:**

- [ ] Abertura de oferta não gera pedido ou pagamento pelo aplicativo.
- [ ] Itens não recebidos não aumentam saldo físico.
- [ ] Compra concluída externamente é identificada como declaração do usuário.

**Dependências:** EP-019, EP-023, EP-009.

**Risco/limite:** Não armazenar credenciais de farmácia nem fingir integração de pagamento.

---

### EP-025 — Privacidade, LGPD, segurança e trilha de acesso

**Frente:** Transversal · **Etapa:** E0–E8 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Proteger dados sensíveis de saúde e impedir acesso indevido.

**Histórias candidatas:**

- `US-025.01` — Implementar isolamento entre famílias, pessoas e permissões por recurso.
- `US-025.02` — Aplicar criptografia em trânsito e proteção de dados locais/armazenados.
- `US-025.03` — Projetar consentimento/base legal, retenção, exportação e exclusão segundo política validada.
- `US-025.04` — Criar logs de acesso administrativo e auditoria de ações críticas sem dados clínicos desnecessários.

**Critérios de aceite do épico:**

- [ ] Testes provam que usuário de outra família não acessa registros.
- [ ] Segredos não entram em repositório nem logs.
- [ ] Checklist jurídico/segurança documenta pendências antes de liberar produção.

**Dependências:** EP-001.

**Risco/limite:** Bases legais, menores, retenção e papéis controlador/operador exigem validação jurídica brasileira.

---

### EP-026 — Qualidade, testes automatizados e validação funcional

**Frente:** Transversal · **Etapa:** E1–E8 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Evitar regressões em funções que afetam horários, estoque e acesso.

**Histórias candidatas:**

- `US-026.01` — Criar testes de domínio, API, autorização, migrações e interface.
- `US-026.02` — Testar idempotência, corrida de atualizações, offline, fusos e lotes.
- `US-026.03` — Implementar dados sintéticos, ambientes de teste e cenários ponta a ponta.
- `US-026.04` — Definir gates de release, regressão e teste de restauração.

**Critérios de aceite do épico:**

- [ ] Fluxos críticos com teste automatizado e registro de execução.
- [ ] Nenhum bug bloqueante clínico/segurança aberto em release.
- [ ] Toda evidência diferencia “implementado”, “testado” e “homologado”.

**Dependências:** EP-004, EP-025.

**Risco/limite:** Testes automatizados não substituem testes físicos de notificações em Android/iOS.

---

### EP-027 — DevOps, observabilidade, backups e operação

**Frente:** Transversal · **Etapa:** E1–E8 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Implantar, monitorar e recuperar o sistema de modo controlado.

**Histórias candidatas:**

- `US-027.01` — Provisionar DEV/HML e PROD isolados, com Docker, secrets e rede segura.
- `US-027.02` — Criar CI/CD, análises estáticas, migrações e rollback planejado.
- `US-027.03` — Instrumentar métricas sem dados sensíveis, alertas de falhas e custos.
- `US-027.04` — Testar backups, restauração, continuidade e procedimento de incidente.

**Critérios de aceite do épico:**

- [ ] Deploy em HML reprodutível com instruções.
- [ ] Restauração em ambiente isolado testada e registrada.
- [ ] Telemetria não expõe prescrições, doses ou medicamentos vinculados à identidade.

**Dependências:** EP-004, EP-025, EP-026.

**Risco/limite:** Produção e contratação de serviços dependem de autorização específica.

---

### EP-028 — Piloto, feedback, suporte e publicação Android/iOS

**Frente:** Lançamento · **Etapa:** E7–E8 · **Prioridade:** P0 · **Escopo:** Núcleo · **Estado:** Proposto

**Resultado esperado:** Colocar versão confiável em uso real e evoluir com retorno mensurado.

**Histórias candidatas:**

- `US-028.01` — Conduzir beta fechado e resolver problemas observados.
- `US-028.02` — Preparar termos, política de privacidade e material das lojas.
- `US-028.03` — Validar requisitos de Android/iOS, permissões e notificações.
- `US-028.04` — Criar canal de suporte, incidentes, releases e feedback.

**Critérios de aceite do épico:**

- [ ] Beta é aceito por critérios definidos, sem falhas críticas abertas.
- [ ] Materiais das lojas descrevem exatamente as funções entregues.
- [ ] Publicação ocorre somente com aprovação explícita e gates concluídos.

**Dependências:** EP-001, EP-025, EP-026, EP-027, EP-015.

**Risco/limite:** Se POC de preços falhar, publicar sem alegar comparação de preços reais.

---

### EP-029 — OCR e importação assistida de prescrições/embalagens

**Frente:** Pós-MVP · **Etapa:** V2 · **Prioridade:** P2 · **Escopo:** Futuro · **Estado:** Proposto

**Resultado esperado:** Diminuir trabalho manual sem delegar decisões clínicas à IA.

**Histórias candidatas:**

- `US-029.01` — Fotografar embalagem e extrair campos candidatos.
- `US-029.02` — Capturar texto de receita com consentimento e segurança.
- `US-029.03` — Apresentar revisão humana de medicamento, dose, unidade e datas.
- `US-029.04` — Registrar origem e erros de interpretação sem inserir automaticamente um plano.

**Critérios de aceite do épico:**

- [ ] Nenhuma extração altera tratamento sem validação explícita.
- [ ] Resultados incertos são marcados como incertos.
- [ ] Imagens têm tratamento de retenção e exclusão aprovado.

**Dependências:** EP-007, EP-012, EP-025.

**Risco/limite:** OCR pode errar doses, grafias e unidades; nunca inferir prescrições autonomamente.

---

### EP-030 — Otimização de cesta, histórico e alertas de preços

**Frente:** Pós-MVP · **Etapa:** V2 · **Prioridade:** P2 · **Escopo:** Futuro · **Estado:** Proposto

**Resultado esperado:** Comparar custo total de múltiplos itens e detectar oportunidades de economia.

**Histórias candidatas:**

- `US-030.01` — Comparar carrinho multimedicação considerando frete e restrições.
- `US-030.02` — Incluir preços por fidelidade e elegibilidade explícitas.
- `US-030.03` — Criar histórico de preços e alerta de queda com licenças válidas.
- `US-030.04` — Explicar economia estimada e sensibilidade à expiração das ofertas.

**Critérios de aceite do épico:**

- [ ] Comparação demonstra premissas e cobertura das farmácias.
- [ ] Alerta de preço indica última verificação e prazo de validade.
- [ ] Histórico só retém dados permitidos por licença/contrato.

**Dependências:** EP-022, EP-023, EP-024.

**Risco/limite:** Sem fontes múltiplas confiáveis e permissão de retenção, recurso permanece desativado.

---

### EP-031 — Relatórios familiares, cuidadores e portabilidade

**Frente:** Pós-MVP · **Etapa:** V2 · **Prioridade:** P2 · **Escopo:** Futuro · **Estado:** Proposto

**Resultado esperado:** Ajudar a interpretar a rotina e compartilhar informações com pessoas autorizadas.

**Histórias candidatas:**

- `US-031.01` — Exibir registros e estatísticas de doses confirmadas/sem confirmação.
- `US-031.02` — Permitir relatório por pessoa e período com autorização.
- `US-031.03` — Exportar registros do titular no formato seguro aprovado.
- `US-031.04` — Notificar cuidador apenas dentro do consentimento e preferências.

**Critérios de aceite do épico:**

- [ ] Relatório não apresenta ausência de registro como não tomada.
- [ ] Exportação respeita autorização da pessoa e minimização de dados.
- [ ] Compartilhamentos e acessos ficam auditáveis.

**Dependências:** EP-006, EP-014, EP-025.

**Risco/limite:** Estatísticas não são recomendação clínica nem prova de adesão terapêutica.

---

### EP-032 — Assistente conversacional e automações assistidas

**Frente:** Pós-MVP · **Etapa:** V2 · **Prioridade:** P2 · **Escopo:** Futuro · **Estado:** Proposto

**Resultado esperado:** Permitir comandos naturais com respostas ancoradas em dados autorizados.

**Histórias candidatas:**

- `US-032.01` — Consultar estoque, agenda e próximas compras com linguagem natural.
- `US-032.02` — Propor ações administrativas sujeitas a confirmação.
- `US-032.03` — Aplicar RAG/consultas estruturadas e autorização por pessoa.
- `US-032.04` — Testar prompt injection, vazamento entre famílias e alucinações.

**Critérios de aceite do épico:**

- [ ] IA não diagnostica, prescreve, substitui ou altera doses.
- [ ] Ações que afetam tratamento, estoque ou compra exigem confirmação.
- [ ] Resposta diferencia dados reais, previsão e informação ausente.

**Dependências:** EP-017, EP-019, EP-025, EP-026.

**Risco/limite:** Não enviar dados sensíveis a modelo externo sem base legal, contrato e avaliação de risco.

---

## 5. Matriz por incremento

| Incremento | Épicos principais | Resultado observável | Gate |
|---|---|---|---|
| **E0 Descoberta** | 001, 002, 003, 025 | Escopo, protótipos e decisões abertas explicitadas | Regras críticas aceitas |
| **E1 Fundação** | 004, 005, 006, 025, 026, 027 | API/mobile iniciados, login e família seguros | CI, autorização e migração |
| **E2 Inventário** | 007, 009, 010; 008/020 se viáveis | Cadastro manual, lotes e movimentações | Saldos e estornos consistentes |
| **E3 Tratamentos** | 012, 013, 014, 017 | Planos versionados, agenda, registro de doses | Sem baixa dupla nem confirmação presumida |
| **E4 Notificações/offline** | 015, 016 | Alertas locais, fila e reconciliação | Teste em dispositivos e cenários de rede |
| **E5 Reposição** | 011, 018, 019, 017 | Validade, previsão, alerta e lista | Projeção reprodutível e estoque intacto |
| **POC-P paralela** | 021; insumos 020 | Decisão GO/NO-GO sobre preços reais | Fonte autorizada, custo e cobertura evidenciados |
| **E6 Comparador condicionado** | 022, 023, 024 | Busca real e redirecionamento externo | Somente com POC aprovada e ofertas rastreáveis |
| **E7 Piloto / E8 Loja** | 025, 026, 027, 028 | Piloto, suporte e publicação | Gate formal, sem bloqueadores |
| **V2 potencial** | 029, 030, 031, 032 | OCR, otimização, relatórios e IA | Repriorizar por evidência e risco |

## 6. Dependências críticas e caminho mínimo

1. `EP-001 → EP-002/003 → EP-004 → EP-005/006` estabelece visão, UX, plataforma e acesso.
2. `EP-007 → EP-009 → EP-010` estabelece a identidade do medicamento e o estoque físico auditável.
3. `EP-012 → EP-013 → EP-014` entrega a agenda e as confirmações; `EP-010` participa da baixa efetiva.
4. `EP-015 + EP-016` torna a experiência diária resiliente; depois `EP-018 → EP-019` conclui reposição.
5. `EP-021 (POC GO) → EP-022 → EP-023 → EP-024` é trilha separada e condicionada de farmácias.
6. `EP-025 + EP-026 + EP-027` são transversais; `EP-028` só pode fechar após os gates definidos.

## 7. Gates específicos para eventos críticos

| Evento | Invariante obrigatória | Evidência exigida |
|---|---|---|
| Confirmar dose | Confirmação explícita por ator autorizado; uma ocorrência não vira duas baixas | Testes idempotência, concorrência e autorização |
| Não confirmar | Sem confirmação continua sem confirmação, mesmo após a janela | Testes de transição de estados e auditoria |
| Adiar | Adia notificação; não altera dose/prescrição silenciosamente | Teste de ocorrência e histórico |
| Alterar plano | Versão anterior e registros já ocorridos preservados | Testes de agenda antes/depois |
| Atualizar estoque | Apenas evento de entrada/saída/ajuste/descarte/estorno validado | Reconciliação de saldo por ledger |
| Projetar falta | Premissas e estoque elegível; não baixa estoque físico | Casos de lote vencido e plano variável |
| Sincronizar | Reenvio de evento não duplica efeitos; conflito explicado | Testes offline/reconexão/multidispositivo |
| Comparar oferta | Apresentação exata, timestamp, fonte, condição, preço conhecido | Amostras reais e testes de match |
| Comprar | Nenhuma compra é realizada sem ação do usuário; redirecionamento não significa pagamento | Testes de fluxo externo e retorno |
| Dados de família | Acesso por pessoa e permissão específica | Testes de isolamento horizontal |

## 8. Definition of Ready (DoR) para qualquer história

- [ ] Ator, motivação, valor e limite de escopo registrados.
- [ ] Regra de negócio e decisões aplicáveis identificadas; ambiguidade bloqueante resolvida.
- [ ] Fluxo UX, estados de erro/vazio/offline e acessibilidade cobertos quando houver interface.
- [ ] Dados, API, permissões e eventual integração/fonte externa documentados.
- [ ] Critérios de aceite testáveis com resultados observáveis e exemplos de borda.
- [ ] Dependências e evidências necessárias listadas.

## 9. Definition of Done (DoD) para qualquer história

- [ ] Implementação integrada, revisão de código e contratos/migrações atualizados.
- [ ] Testes relevantes executados e resultados registrados; falhas não ocultadas.
- [ ] Testes de segurança/autorização e eventos críticos conforme impacto.
- [ ] Documentação, ADR (se houver), status real e release notes atualizados.
- [ ] Aprovado em HML e homologado pelo responsável quando necessário.
- [ ] Nenhuma função simulada é apresentada como integração real.

## 10. Métricas de produto e engenharia (sem metas inventadas)

- **Uso:** taxa de planos configurados corretamente, conclusão de primeiro cadastro, usuários ativos.
- **Agenda:** doses confirmadas por ação explícita, proporção sem confirmação, falhas de agendamento reportadas.
- **Estoque:** divergência entre saldo informado e conferência física, estornos, erros de unidade.
- **Reposição:** previsões testáveis, alertas vistos, itens comprados/recebidos e faltas evitadas declaradas.
- **Preços:** cobertura por CEP/apresentação, taxa de correspondência exata, frescor, economia comparável, custo por consulta.
- **Confiabilidade:** sincronizações sem erro, duplicidade evitada, taxas de crash, recuperação de backup e incidentes.
- **Privacidade:** tentativas de acesso negadas, solicitações do titular tratadas e incidentes de dados.

## 11. Decisões pendentes antes de implementação crítica

1. Escopo familiar do primeiro beta e modelo de autorização de cuidadores/menores.
2. Doses fracionárias, líquidos, múltiplas apresentações e uso sob demanda.
3. Política de horário, tolerância, fusos e adiamento de lembrete.
4. Divergência estoque real vs. saldo offline, estorno e correções.
5. Disponibilidade e licenças de catálogo GTIN, preços, frete e disponibilidade.
6. Tratamento de dados sensíveis, retenção, mecanismos de consentimento e publicação.

**Próxima ação do agente:** refinar `EP-001` a `EP-007` em histórias de primeira entrega e propor uma fatia vertical com login/família, cadastro manual de medicamento e primeiro movimento auditável; executar somente após decisões bloqueantes.

**Documentos relacionados:** `01-visao-produto.md`, `02-prd.md`, `03-jornadas.md`, `04-regras-negocio.md`, `05-arquitetura.md`, `06-design-system.md`, `07-modelo-dados.md`, `08-contratos-api.md`, `09-integracoes.md`, `10-seguranca.md`, `11-testes.md`, `13-roadmap.md`, `14-decisoes.md`, `15-status-projeto.md`.
