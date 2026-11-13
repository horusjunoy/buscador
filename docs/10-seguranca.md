# 10 — Segurança, LGPD e segurança clínica

**Versão:** 0.1 · **Status:** POLÍTICA PROPOSTA; parecer jurídico e avaliação de riscos necessários antes do lançamento.

## Classificação de dados

- **Críticos/sensíveis:** pessoa identificada + medicamento, dose, frequência, histórico, prescrição, características clínicas e hábitos inferíveis.
- **Pessoais:** nome, contatos, vínculos familiares, contas, CEP preciso quando associado à pessoa.
- **Operacionais:** telemetria técnica, fonte de catálogo, eventos agregados sem identificação direta.

Informação de saúde ligada a pessoa identificada ou identificável é dado pessoal sensível pela LGPD. **Não presumir que consentimento genérico basta**: definir hipótese legal apropriada para cada finalidade, especialmente para menores e compartilhamento de dados.

## Threat model inicial

| Ameaça | Controle prioritário | Teste |
|---|---|---|
| Usuário lê dados de outra família | Escopo por tenant, autorização por recurso, deny-by-default | IDOR/BOLA cruzado |
| Cuidador altera tratamento sem permissão | Permissões granulares por pessoa/ação | RBAC/ABAC negativos |
| Ataque de repetição duplica baixa | Idempotência, constraints, transações | Replay em paralelo |
| Vazamento por logs, push e analytics | Minimização, redaction, notificações discretas | Inspeção de logs/payload |
| Roubo do celular | Sessões, armazenamento protegido, bloqueio opcional | Teste offline/logout |
| Integração maliciosa/comprometida | Egress control, validação de URL, timeouts, segredos por provedor | Teste de abuso/SSRF |
| Perda de banco/corrupção | Backups cifrados, restore, integridade de movimentos | Restore ensaiado |
| Upload de documento de receita | Restrição de tipos, antimalware, criptografia, acesso restrito | Testes de upload, se implementado |

## Autenticação e autorização

- Padrão de autenticação seguro com política de expiração, revogação e recuperação; MFA para perfis administrativos e operação.
- Permissões mínimas por pessoa e finalidade, independentes do papel genérico de membro da família.
- Convites com prazo e confirmação de titular/responsável; revogação auditada e efetiva.
- APIs escondem recursos de outros tenants e retornam respostas sem vazar existência.
- Contas de operação não precisam de acesso direto a prontuário/medicamentos; auditoria de acesso de suporte deve ser excepcional e justificada.

## Proteção técnica

- TLS em trânsito; criptografia em repouso para bancos/backups/arquivos; chaves fora do código.
- Credenciais em secret manager ou mecanismo equivalente da infraestrutura; rotação e segregação de ambiente.
- Dados offline minimizados e protegidos com keystore/keychain e estratégias móveis adequadas.
- Logs estruturados sem conteúdo de medicamento/dose/pessoa; IDs técnicos que não revelam informação sensível.
- Rate limiting, proteção contra abuso, validação de payload, scan de dependências e revisão de autorização.
- Retenção/descarte limitados por finalidade; backups têm prazo e processo de expurgo adequado.
- Plano de incidentes, detecção, registro, resposta e avaliação de obrigação de notificação.

## Privacidade by design

1. Mapear finalidades e categorias de dados em um inventário de tratamento.
2. Definir base legal válida, transparência e papéis controlador/operador.
3. Segregar tratamento assistencial registrado de marketing, afiliados ou analytics.
4. Não comercializar nem transferir dados clínicos para farmácias com o objetivo de publicidade comportamental.
5. Preservar exercício de direitos: acesso, informação, correção, exportação e exclusão quando aplicável, com rastreabilidade.
6. Avaliar necessidade de Relatório de Impacto à Proteção de Dados Pessoais (RIPD) e revisão jurídica em tratamentos de maior risco.
7. Definir política específica para menores, representação e capacidade de consentimento/autorização.
8. Examinar contratos e transferências internacionais antes de serviços de nuvem/analytics externos.

## Segurança clínica e ética

- Dado **prescrito ou orientado pelo profissional** é distinto de **dado cadastrado pelo usuário** e de **estimativa do sistema**.
- O aplicativo não valida se uma dose é clinicamente adequada, não modifica prescrições e não recomenda compensação de dose esquecida.
- Não transformar uma notificação entregue em prova de ingestão.
- Desconhecido é desconhecido: dose sem resposta permanece sem confirmação.
- Recomendações de economia não equivalem a autorização de troca por genérico/similar.
- Mensagens de exceção devem encaminhar o usuário às orientações do seu profissional de saúde, sem sugerir conduta específica.
- A necessidade de enquadramento regulatório de software em saúde deve ser avaliada conforme funcionalidades efetivas antes do lançamento; evitar alegar conformidade sem análise.

## Gates antes de produção

- Revisão jurídica de LGPD, termos, privacidade e políticas de dados de menores.
- Modelo de ameaças revisado, autorização e pentest focados em BOLA/IDOR.
- Reconstituição de estoque, idempotência e auditoria verificadas.
- Teste de exportação/exclusão e de retenção/backup.
- Revisão da descrição das funcionalidades perante regulação aplicável.
- Plano de resposta a incidente aprovado e ensaiado.

## Fontes para revisão jurídica/técnica

- [Ministério da Saúde — LGPD](https://www.gov.br/saude/pt-br/acesso-a-informacao/lgpd)
- [ANPD — Perguntas frequentes e bases legais](https://www.gov.br/anpd/pt-br/acesso-a-informacao/perguntas-frequentes)
- [ANPD — guia de segurança para pequeno porte](https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia-orientativo-sobre-seguranca-da-informacao-para-agentes-de-tratamento-de-pequeno-porte)

**Relações:** `05-arquitetura.md`, `07-modelo-dados.md`, `11-testes.md`.
