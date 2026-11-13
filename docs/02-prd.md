# 02 — PRD (Documento de Requisitos do Produto)

**Versão:** 0.1 · **Data:** 12/11/2026 · **Status:** PROPOSTO

## 1. Resultado pretendido

Um MVP mobile que conecta: catálogo/cadastro → plano de uso informado → lembrete → confirmação → baixa de estoque → previsão de reposição → comparação de oferta real quando disponível. O funcionamento de agenda e estoque **não depende** de haver conectores de farmácias prontos.

## 2. Perfis e escopo

- **Titular:** gerencia a própria conta e autoriza acessos.
- **Pessoa acompanhada:** membro familiar com registros isolados e permissões adequadas.
- **Cuidador autorizado:** observa ou registra ações apenas dentro de permissões específicas.
- **Administrador técnico:** atua na infraestrutura, sem acesso irrestrito a dados clínicos em produção.

## 3. Requisitos funcionais

| ID | Requisito | Prioridade MVP | Critério resumido |
|---|---|---|---|
| FR-001 | Criar conta e autenticar | P0 | Fluxo de sessão, recuperação e logout testados |
| FR-002 | Criar perfis familiares | P0 | Isolamento entre famílias e validação de autorização |
| FR-003 | Cadastrar medicamento/apresentação | P0 | Nome, forma, força, unidade, identificadores opcionais |
| FR-004 | Pesquisar catálogo e cadastrar manualmente | P0 | Sem depender de API externa; origem do dado registrada |
| FR-005 | Cadastrar lotes de estoque | P0 | Quantidade, unidade, validade, compra e responsável |
| FR-006 | Criar plano de uso informado pelo usuário | P0 | Dose, horários, frequência, início/fim, fuso |
| FR-007 | Gerar ocorrências de dose | P0 | Idempotência e preservação de histórico |
| FR-008 | Notificar doses agendadas | P0 | Autorizações, falhas e limites do SO tratados |
| FR-009 | Registrar confirmação e ações | P0 | Tomada, não tomada informada, adiada, sem confirmação |
| FR-010 | Baixar estoque após confirmação | P0 | Uma única movimentação por consumo confirmado |
| FR-011 | Corrigir registros com auditoria | P0 | Reversão/ajuste rastreáveis; não apagar fatos |
| FR-012 | Calcular previsão de consumo | P0 | Projeção separada do estoque real e ressalvas |
| FR-013 | Alertar baixo estoque/vencimento | P0 | Threshold configurável; sem alarme clínico implícito |
| FR-014 | Organizar lista de compras | P0 | Adicionar/remover/concluir com histórico básico |
| FR-015 | Buscar ofertas e comparar custo total | P1 condicionado | Apenas fontes autorizadas e ofertas verificáveis |
| FR-016 | Identificar condições de oferta | P1 condicionado | Fidelidade, quantidade, frete, disponibilidade e timestamp |
| FR-017 | Abrir oferta selecionada | P1 condicionado | Destino válido e preço sujeito a confirmação |
| FR-018 | Sincronizar registros offline | P0 | Sem duplicação de confirmação ou baixas |
| FR-019 | Consultar histórico por pessoa | P0 | Registros corretos, por período, acessos autorizados |
| FR-020 | Ler código de barras | P1 | Produto validado pelo usuário; fallback manual |
| FR-021 | Exportar e excluir dados sob regras aplicáveis | P1 obrigatório antes de produção | Exercício de direitos com verificação de titularidade |

P0 = necessário para MVP funcional de gestão; P1 condicionado = depende de viabilidade/integrador; P1 obrigatório = gate antes de disponibilização pública.

## 4. Requisitos não funcionais

| ID | Requisito | Proposta de aceite |
|---|---|---|
| NFR-001 | Privacidade | Menor privilégio, nenhuma informação clínica em logs, base legal revisada |
| NFR-002 | Integridade | Movimentos auditáveis, transações atômicas, idempotência |
| NFR-003 | Offline | Visualizar agenda e registrar ação em fila criptografada/segura |
| NFR-004 | Sincronização | Reconciliação determinística; conflitos não descartados silenciosamente |
| NFR-005 | Acessibilidade | WCAG 2.2 AA como meta adaptada, fonte escalável e leitor de tela |
| NFR-006 | Segurança | Testes de autorização horizontal, gestão de segredos, TLS e backup |
| NFR-007 | Observabilidade | Correlation ID, métricas técnicas sem dados sensíveis |
| NFR-008 | Manutenibilidade | Módulos com testes, OpenAPI, migrations e CI obrigatório |
| NFR-009 | Disponibilidade | SLO definido após piloto; sem promessa de 100% para notificações |
| NFR-010 | Precisão | Nenhuma equivalência automática de concentração, apresentação ou genérico |

## 5. Restrições clínicas e de segurança

1. Registro de posologia serve para reproduzir informação recebida do profissional/usuário; a aplicação não recomenda ajustes.
2. Confirmação requer ação explícita; silêncio não pode virar "tomada" ou "não tomada".
3. Uma dose sem confirmação deve continuar com status auditável independente.
4. O app não sugere compensar dose, tomar em dobro, suspender ou trocar o produto.
5. Sugestão de economia nunca deve equivaler a recomendação terapêutica.
6. A pessoa pode marcar dose tomada sem estoque suficiente; registrar inconsistência e pedir conciliação, sem falsificar dado de estoque.

## 6. Premissas e dependências

- **A validar:** existência, licença, custo e cobertura de catálogo e preços de farmácias.
- **A validar:** regras de uso de dados de empresas parceiras; não presumir API pública.
- **A validar:** performance dos alarmes por fabricante/modelo, com testes reais.
- **A validar:** desenho jurídico de bases legais para tratamento de dados sensíveis, menores e tutores.
- **Decisão proposta:** monólito modular; versões estáveis das stacks serão fixadas ao iniciar o código.

## 7. Critérios de pronto do MVP

- Fluxo completo de cadastro → plano → ocorrência → confirmação → estoque → reposição funciona em Android e iOS em dispositivos reais.
- Correção/reversão e sincronização não geram baixa dupla.
- Usuário consegue operar com notificações negadas e sem internet, com limites claramente informados.
- Controle de acesso, exportação e exclusão seguem política validada; recuperação de backups foi testada.
- Comparação mostra apenas oferta real autorizada; se indisponível, exibe indisponibilidade verificável, sem inventar preço.
- PRD, API, modelo de dados, testes e status atualizados; aceite documentado.

## 8. Fora do escopo inicial

Prescrição automática, interpretação clínica de receita por IA, telemedicina, recomendações de interação, compra automática, carteira de receita controlada e integração com prontuário, salvo projeto próprio com revisão regulatória.

**Relações:** `03-jornadas.md`, `04-regras-negocio.md`, `11-testes.md`, `13-roadmap.md`.
