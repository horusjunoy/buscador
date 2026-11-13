# 19 — Mapa de telas, rotas, estados e ações (MVP)

**Status:** especificação canônica de UI. **Idioma inicial:** pt-BR. **Referência de estética:** `assets/references/01-home-original.png` (verde/turquesa). As imagens são desenhos ilustrativos, não layouts 1:1 nem fontes de dados verdadeiros.

## Sistema de navegação

Barra inferior canônica (autenticado): **Início**, **Medicamentos**, **Agenda**, **Estoque**, **Mais**. Acesso à **Busca de preços** e **Lista de compras** com CTA de destaque na Home, em Estoque e em Mais. Ações com risco clínico, financeiro ou de privacidade exigem rótulos literais e confirmação apropriada. Apoiar navegação por leitor de tela.

### Cadastro / primeiro uso

| Tela | Rota sugerida | Conteúdo | Ações e destino | Estados críticos |
|---|---|---|---|---|
| UI-01 Splash | `/splash` | marca + loading | redirecionar por status de sessão | timeout, offline |
| UI-02 Onboarding | `/onboarding` | benefícios: doses, estoque, economia e privacidade | continuar, pular → autenticação | texto escalável |
| UI-03 Login | `/auth/login` | e-mail, senha, acesso seguro | entrar, recuperar, cadastrar | credencial inválida, bloqueio |
| UI-04 Cadastro | `/auth/signup` | conta, aceite de documentos, verificação | criar conta | verificação, duplicidade |
| UI-05 Recuperar acesso | `/auth/recover` | pedido de restauração | solicitar link/código | mensagem neutra anti-enumeração |
| UI-06 Selecionar pessoa | `/profiles/select` | cartões das pessoas autorizadas | escolher / criar pessoa | sem acesso, revogação |
| UI-07 Criar perfil | `/profiles/new` | nome/apelido, preferências mínimas e vínculo | salvar | menores, permissões |

### Operação diária

| Tela | Rota sugerida | Conteúdo | Ações e destino | Estados críticos |
|---|---|---|---|---|
| UI-08 Home / Hoje | `/home` | pessoa selecionada, próximas doses, alertas, atalho preços | confirmar/adiar, agenda, estoque, buscar | **vazio sem dados sintéticos**; offline |
| UI-09 Agenda | `/agenda` | dia/semana, ocorrências por estado | detalhe, confirmar, não tomei, adiar | sem confirmação, fuso |
| UI-10 Detalhe da dose | `/doses/:id` | apresentação, horário, origem, status e histórico | `Tomei`, `Não tomei`, `Adiar` | concorrência, falta de saldo |
| UI-11 Confirmação | `/doses/:id/confirm` | resumo + ação clara + possível estoque | confirmar evento | resultado local ainda não sincronizado |
| UI-12 Histórico de doses | `/doses/history` | filtros, autor, horário real, correções | abrir evento; corrigir com trilha | não apagar silenciosamente |

### Medicamentos e tratamentos

| Tela | Rota sugerida | Conteúdo | Ações e destino | Estados críticos |
|---|---|---|---|---|
| UI-13 Meus medicamentos | `/medications` | pesquisa e lista por perfil | detalhe, adicionar | duplicado, vazio |
| UI-14 Buscar catálogo | `/medications/catalog` | consulta por nome/GTIN | selecionar apresentação | sem fonte, match incerto |
| UI-15 Adicionar manual | `/medications/new` | nome, substância, concentração, forma, unidades | salvar e revisar | faltam campos críticos |
| UI-16 Escanear código | `/medications/scan` | câmera/GTIN confirmado | localizar/confirmar | permissão negada e GTIN desconhecido |
| UI-17 Detalhe medicamento | `/medications/:id` | apresentação, planos, lotes, validades | editar, novo plano, estoque | dados inconsistentes |
| UI-18 Tratamentos | `/treatments` | planos ativos, temporários, concluídos | criar/editar/suspender conforme orientação | preservar histórico |
| UI-19 Editor de plano | `/treatments/:id/edit` | pessoa, apresentação, doses e horários informados | pré-visualizar, salvar versão | unidade inválida, fuso |
| UI-20 Prévia de agenda | `/treatments/:id/preview` | próximas ocorrências e alertas | confirmar cadastro | DST, recorrência, fim |

### Estoque e reposição

| Tela | Rota sugerida | Conteúdo | Ações e destino | Estados críticos |
|---|---|---|---|---|
| UI-21 Estoque | `/inventory` | saldo por apresentação, unidade, alertas | ver lotes, movimentar, adicionar | sem lote, estoque zero |
| UI-22 Lotes/validade | `/inventory/:productId/lots` | lote, validade, quantidade e proveniência | detalhar, ajustar, descartar | vencido/embalagem desconhecida |
| UI-23 Registrar movimento | `/inventory/movements/new` | entrada, saída, ajuste, descarte, unidade | confirmar transação | duplicidade, saldo insuficiente |
| UI-24 Histórico estoque | `/inventory/history` | livro-razão e autoria | filtrar, conciliar | imutabilidade da trilha |
| UI-25 Alertas | `/alerts` | baixo estoque, vencimentos, doses sem confirmação | abrir contexto, configurar | offline, duplicados |
| UI-26 Lista de compras | `/shopping-list` | itens sugeridos e manuais | buscar oferta, marcar recebido | abrir oferta não altera estoque |
| UI-27 Confirmar recebimento | `/shopping-list/:id/receive` | quantidade recebida, lote, validade | registrar entrada | diferença entre pedido e entregue |

### Preços reais, família e conta

| Tela | Rota sugerida | Conteúdo | Ações e destino | Estados críticos |
|---|---|---|---|---|
| UI-28 Busca preços | `/prices/search` | produto/apresentação, CEP, filtro de aquisição | consultar fontes | sem integração, limite cobertura |
| UI-29 Resultados comparados | `/prices/results` | fontes, preço item/frete/preço final, tempo, disponibilidade | abrir oferta, comparar | dados vencidos e condições |
| UI-30 Detalhe oferta | `/prices/offers/:id` | loja, origem, preço/condições, timestamp e validade | ir para farmácia externa | redirecionamento seguro |
| UI-31 Família e permissões | `/family` | pessoas, convites, escopos | convidar, revogar, escolher | acesso negado |
| UI-32 Mais / Ajustes | `/more` | compras, perfil, notificações, privacidade e ajuda | telas de configuração | preferências conflitantes |
| UI-33 Notificações | `/settings/notifications` | permissão, teste e horários | atualizar preferências | restrições SO |
| UI-34 Privacidade | `/settings/privacy` | acesso, exportação, exclusão e política | solicitar/confirmar | exigências legais |
| UI-35 Ajuda/erros | `/help` | suporte e problemas comuns | FAQ, contato | não expor dados clínicos |

### Telas não obrigatórias no MVP

Relatórios analíticos completos (EP-031), leitura OCR de receita (EP-029), histórico inteligente/otimização multiloja (EP-030) e chat de IA (EP-032) são V2. Pranchas que mostram essas telas são **referências de visão futura**, não compromisso de escopo do MVP.

## Regras de estado compartilhadas

- **Dose:** `programada`, `pendente`, `adiada`, `tomada_confirmada`, `nao_tomada_declarada`, `sem_confirmacao`, `cancelada`. Uma dose atrasada pode ficar em `sem_confirmacao`, nunca transicionar automaticamente para `nao_tomada_declarada`.
- **Estoque:** positivo, zero, baixo, a vencer, vencido, pendente de reconciliação. Diferenciar `saldo_fisico` de `saldo_projetado`.
- **Oferta:** `confirmada_na_fonte`, `indisponivel`, `expirada`, `preco_sem_condicoes`, `erro_fonte`, `sem_cobertura`. Nunca exibir informação expirada como preço válido atual.
- **Rede:** `online`, `offline`, `sincronizando`, `aguardando_sincronizacao`, `conflito`, `erro`. Status visível nas operações importantes.
- **Formulários:** loading, vazio, erro de rede, erro de validação, conflito 409, não autorizado 403 e sucesso com resultado explícito.

## Acessibilidade e UX

Áreas de toque de pelo menos 44x44pt equivalentes; contrastes verificados para texto, tamanhos escaláveis, labels e ordem semântica; alertas com texto e ícone; não depender de gestos ocultos. Revisar acessibilidade com leitores de tela Android/iOS e no mínimo uma rodada com pessoa não técnica.

## Critério para considerar uma tela pronta

Interface em Flutter seguindo tokens, navegação funcional, dados do backend ou cache verificados, estados críticos e offline, autorização e acessibilidade; cobertura de widget/e2e adequada; screenshots reais de dispositivo; aceite do comportamento. Mockup isolado não conta.
