# 06 — Design System, UX e acessibilidade

**Versão:** 0.1 · **Status:** PROPOSTO (tokens e interface finais dependem de protótipos e testes com usuários)

## Princípios de interface

1. **Clareza sobre inferência:** status de dose e estoque mostram fatos observados versus estimativas.
2. **Ação principal sem ambiguidade:** confirmar ingestão não pode acontecer por toque acidental isolado ou no lugar de "visualizar".
3. **Acessível para pessoas de idades diversas:** tipografia escalável, alto contraste, alvos de toque adequados e leitura assistiva.
4. **Nunca depender só de cor:** cada status usa texto e ícone.
5. **Privacidade contextual:** em notificações bloqueadas, oferecer conteúdo discreto que não exponha medicamento/condição sem autorização.
6. **Feedback e recuperação:** ações críticas confirmadas, reversão auditável, estados offline e conflitos visíveis.

## Navegação proposta

Barra inferior com quatro áreas: `Hoje`, `Medicamentos`, `Comprar`, `Família/Perfil`. Em `Hoje`: próximo horário, ocorrências em aberto, histórico do dia. Em `Medicamentos`: estoque, apresentações, planos e vencimentos. Em `Comprar`: lista e ofertas. Em `Família`: permissões e ajustes.

## Tokens iniciais (propostas, não cores definitivas)

| Grupo | Token | Regra |
|---|---|---|
| Cor | `color.surface`, `color.text` | Temas claro/escuro; contraste validado |
| Cor | `color.primary` | Ações primárias; sem semântica clínica |
| Estado | `status.confirmed`, `status.pending`, `status.unconfirmed`, `status.skipped`, `status.snoozed` | Sempre com rótulo e ícone |
| Tipografia | `font.body`, `font.label`, `font.heading` | Suportar escalonamento do sistema |
| Espaçamento | `space.1=4`, `space.2=8`, `space.3=12`, `space.4=16`, `space.6=24`, `space.8=32` | Unidades de design em dp/pt conforme plataforma |
| Raio | `radius.sm=8`, `radius.md=12`, `radius.lg=16` | Consistência, não decorar excessivamente |
| Alvo | `tapTarget.min` | >= 44x44 pt (iOS) e preferencialmente >= 48x48 dp (Android) |

Definir paleta final após checar contraste e semântica. **Vermelho não deve significar automaticamente falha clínica:** "sem confirmação" e "não tomada informada" são estados distintos.

## Biblioteca de componentes

- `MedicationIdentityTile`: nome, concentração, forma e embalagem visíveis.
- `DoseCard`: pessoa, dose, horário programado, status, ações disponíveis e versão do plano.
- `DoseActionSheet`: Tomei / Não tomei / Adiar / Cancelar, confirmação de quantidade, feedback e correção posterior.
- `StockBatchCard`: quantidade, unidade, lote, validade, origem.
- `StockStatus`: saldo real, consumo projetado, divergências e confiança da previsão.
- `ReplenishmentAlert`: data estimada e antecedência selecionada.
- `OfferCard`: nome exato, preço item, frete/serviço, custo total, fonte, timestamp, fidelidade, disponibilidade.
- `PersonSwitcher`: seleção clara de perfil com autorização.
- `SyncStatus`: sincronizado, aguardando rede, conflito, falha recuperável.
- `EmptyState`, `ErrorState`, `OfflineState`, `PermissionState` e `LoadingState` para cada tela.

## Conteúdos e microcopy recomendados

| Situação | Texto aprovado como exemplo |
|---|---|
| Dose ainda não marcada | "Aguardando confirmação" |
| Após registro de uso | "Dose registrada como tomada" |
| Horário passou sem ação | "Sem confirmação de uso" |
| Usuário declarou não uso | "Registrada como não tomada" |
| Estoque baixo | "Estoque estimado para mais 5 dias, considerando o plano atual" |
| Preço sem prova | "Nenhuma oferta verificada no momento" |
| Link para farmácia | "Preço e disponibilidade sujeitos à confirmação na farmácia" |
| Falha de sincronização | "Registro salvo neste dispositivo; aguardando sincronização" |

Evitar "Você esqueceu" ou "Você perdeu a dose" se o evento não foi confirmado pela pessoa.

## Acessibilidade e inclusão

- Rótulos sem abreviações críticas, suporte a leitor de tela, ordem de foco coerente e contraste WCAG 2.2 AA como meta.
- Suporte a text scaling sem truncar concentração/dose.
- Diferenciação entre horários programados, efetivos e registrados.
- Erros de entrada com descrição, não apenas borda vermelha.
- Operações críticas com confirmação e caminho de correção.
- Não exibir nome de medicamento em tela bloqueada sem escolha do usuário.

## Protótipos mínimos a validar

1. Onboarding e primeira pessoa.
2. Cadastro de medicamento manual vs. por catálogo.
3. Criação/edição de plano de uso.
4. Lembrete e confirmação com estoque insuficiente.
5. Tela de estoque com lote vencendo.
6. Lista de compras e ofertas com fonte obsoleta.
7. Fluxo offline/erro/sincronização.

## Critérios para aceitar um componente

Especificação de estados e tamanhos, comportamento acessível, testes de widget, visual claro/escuro, microcopy revisada, interação com um dedo, política de privacidade da tela e documentação em catálogo de componentes.

**Relações:** `03-jornadas.md`, `04-regras-negocio.md`, `11-testes.md`.
