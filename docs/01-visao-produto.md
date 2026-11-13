# 01 — Visão do produto

**Versão:** 0.1 · **Data:** 12/11/2026 · **Status:** PROPOSTO

## Problema

Pessoas e famílias frequentemente não têm uma visão única de quais medicamentos possuem, quem utiliza cada medicamento, quando devem tomar as doses, quanto estoque resta e onde comprar pelo menor custo total. A combinação de lembretes isolados, caixas físicas e pesquisas manuais gera esquecimento, compras tardias, perdas por validade e esforço repetitivo.

## Visão

Ser o assistente pessoal e familiar que integra **medicamento certo, uso registrado, estoque confiável e reposição economicamente informada** em um só aplicativo.

## Proposta de valor

- **Para quem usa:** visualizar horários, confirmar uso, consultar histórico e não ficar sem itens por desorganização.
- **Para cuidadores autorizados:** acompanhar pessoas sob seus cuidados respeitando limites de acesso.
- **Para a família:** inventário compartilhável, controle de lotes e organização de compras.
- **Para quem compra:** comparar ofertas verificáveis, preço total e condições antes de seguir para a farmácia.

## Público inicial

1. Adultos com uso contínuo ou temporário e smartphone.
2. Responsáveis pela organização de medicamentos da família.
3. Cuidadores designados, com autorização para perfis específicos.

**A validar:** foco prioritário do MVP (uso individual vs. gestão familiar desde o dia 1), regiões/cidades iniciais de comparação de preços e necessidades de cuidadores.

## Jobs to be done

- Quando recebo orientação de tratamento, quero registrar dose e horários sem ambiguidade.
- Quando chega o horário, quero um lembrete inteligível e confirmar o que aconteceu.
- Quando alguém usa um medicamento, quero saber o impacto no estoque real.
- Antes de acabar, quero ser avisado e comparar possibilidades de compra.
- Quando tenho medicamento perto da validade, quero visualizar o risco de desperdício sem receber orientação clínica automática.

## Objetivos do MVP

- Permitir cadastrar pessoas, produtos, lotes e orientações de uso.
- Criar, exibir e registrar ocorrências de doses com histórico e estados explícitos.
- Atualizar estoque real com transações confirmadas, com correções rastreáveis.
- Calcular projeção de reposição, com alertas e ressalvas de confiança.
- Possibilitar busca e comparação de preços **apenas se houver fonte real autorizada**; caso contrário apresentar claramente "sem ofertas verificadas" e permitir lista de compras.
- Funcionar parcialmente offline para agenda e registros, com sincronização segura.

## Não objetivos do MVP

- Diagnóstico, recomendação de dose, mudança de prescrição, substituição automática, aconselhamento sobre dose esquecida ou interações clínicas.
- Marketplace com checkout próprio, pagamentos, entrega própria, gestão de receita controlada e compras automáticas.
- Promessa de alerta infalível do sistema operacional.
- Comparador nacional completo antes de validar integrações reais.

## Diferenciais buscados

1. Um único fluxo entre prescrição informada, lembrete, confirmação, estoque e compra.
2. Diferença explícita entre estoque observado e consumo projetado.
3. Proveniência, recência e condições nas ofertas exibidas.
4. Privacidade e controles familiares desde a arquitetura.

## Métricas propostas (não metas aprovadas)

| Métrica | Definição | Evidência |
|---|---|---|
| Ativação | Perfil com 1 item + 1 plano de uso ou estoque inicial | Evento analítico sem dado clínico identificável |
| Confiabilidade do registro | % das confirmações válidas sem duplicação de baixa | Testes + métricas agregadas |
| Cobertura de agenda | % ocorrências esperadas materializadas corretamente | Testes por calendário/fuso |
| Alertas úteis | % alertas de reposição gerados antes da ruptura projetada | Cenários controlados |
| Ofertas verificadas | % pesquisas com fonte, timestamp, identificação e condição | Auditoria de conectores |
| Adoção | Retenção e uso das funções essenciais, com consentimento apropriado | Métricas agregadas |

## Valores de produto

**Confiabilidade > velocidade de entrega > sofisticação visual > funcionalidades de IA.** A interface deve ser clara para usuários não técnicos, incluindo idosos. Nenhum usuário deve precisar confiar em uma inferência silenciosa do aplicativo para entender o que tomou ou precisa comprar.

## Perguntas abertas

- O MVP inicia com **uma conta e vários perfis familiares** ou com multiusuário colaborativo já na primeira versão?
- Qual faixa etária deve orientar os primeiros testes de usabilidade?
- O foco comercial será Brasil inteiro ou piloto regional?
- O modelo de negócio será gratuito, assinatura ou parcerias (evitar incentivos que distorçam a comparação)?

**Relações:** `02-prd.md`, `03-jornadas.md`, `13-roadmap.md`.
