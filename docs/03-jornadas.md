# 03 — Jornadas, histórias e critérios de aceitação

**Versão:** 0.1 · **Status:** PROPOSTO

## Perfis de referência (hipóteses, não pesquisa com usuários)

- **Pessoa autônoma:** acompanha os próprios medicamentos e prefere poucos toques.
- **Responsável familiar:** gerencia estoque físico compartilhado e agendas individuais.
- **Cuidador:** precisa distinguir o que viu, lembrou e confirmou, sem presumir ingestão.
- **Pessoa idosa:** depende de letras maiores, botões explícitos e mensagens legíveis.

## Jornada J01 — Primeiro acesso e família

1. Criar conta e verificar identidade.
2. Aceitar termos e receber transparência sobre dados de saúde.
3. Criar perfil próprio e, quando aplicável, outros perfis vinculados.
4. Definir quem pode visualizar, confirmar uso, editar estoque ou administrar o perfil.
5. Cadastrar primeiro medicamento manualmente ou via catálogo, sempre confirmando a apresentação.

**Aceite J01:** um perfil nunca consegue acessar dados de outra família sem concessão válida; perfis sem autorização não aparecem nas buscas e históricos.

## Jornada J02 — Cadastro do medicamento e lote

1. Buscar por nome ou ler código de barras (quando disponível).
2. Confirmar princípio ativo, concentração, forma, embalagem e unidade.
3. Se o produto não existir, cadastrar manualmente com origem "usuário".
4. Informar unidades em casa, validade e lote opcional com campos condicionais.
5. Ver saldo atual, por lote e agregado, sem projetar consumo como saída real.

**Aceite J02:** não converter automaticamente 1 caixa em comprimidos sem conhecer a quantidade por embalagem; produtos semelhantes não são mesclados silenciosamente.

## Jornada J03 — Registrar plano de uso

1. Selecionar pessoa e apresentação.
2. Informar dose, unidade, horários locais, recorrência, início e eventual término.
3. Conferir resumo com fuso horário e origem da orientação.
4. Salvar; aplicação gera ocorrências futuras em janela móvel e agenda lembretes locais.

**Aceite J03:** alteração de plano preserva histórico; horários futuros obedecem à nova versão; intervalo passado não é reescrito.

## Jornada J04 — Tomar ou não tomar

1. No horário, receber lembrete (se permissões/SO permitirem).
2. Abrir registro e escolher **Tomei**, **Não tomei**, **Adiar** ou deixar **Sem confirmação**.
3. Para Tomei, gravar pessoa, responsável pela confirmação, horário ocorrido e horário informado quando distintos.
4. Produzir movimentação de estoque uma única vez, com correção auditável quando necessário.
5. Refletir status e histórico imediatamente; sincronizar quando houver internet.

**Aceite J04:** tocar duas vezes, repetir requisição, restaurar conexão e registrar em dois dispositivos não pode causar consumo duplo. Falta de resposta nunca vira "Não tomei".

## Jornada J05 — Reposição

1. Consumir ocorrências confirmadas e consultar estoque físico disponível.
2. Projetar duração com base no plano vigente, considerando dias sem consumo e data de validade.
3. Calcular antecedência configurada para compra, apresentando nível de confiança.
4. Gerar alerta e permitir incluir na lista.
5. Permitir registrar compra/reentrada de estoque após confirmação real.

**Aceite J05:** projeção não altera o saldo; se faltar dado confiável, comunicar "previsão indisponível".

## Jornada J06 — Comparação de preços

1. Selecionar apresentação exata (produto, forma, concentração, embalagem).
2. Definir cidade/CEP, retirada ou entrega, quantidade e possível fidelidade.
3. Consultar fontes autorizadas com identificação de data/hora de coleta.
4. Exibir preço item, taxas/frete, preço total e indisponibilidades/incertezas.
5. Escolher oferta e abrir loja; efetivação/preço final confirmados no canal da farmácia.

**Aceite J06:** não ordenar ofertas de preço unitário mais barato acima de oferta de custo total mais baixo sem explicar o critério; não afirmar "em estoque" sem prova atual.

## Histórias de usuário prioritárias

| ID | Como... quero... para... | Critério de aceitação |
|---|---|---|
| US-01 | usuário, cadastrar um medicamento manualmente | Para operar sem catálogo externo |
| US-02 | usuário, confirmar dose | Ter histórico auditável e baixa única |
| US-03 | usuário, corrigir confirmação | Reverter efeitos sem apagar auditoria |
| US-04 | responsável, visualizar estoque da família | Controlar validade e unidade corretamente |
| US-05 | usuário, adiar lembrete | Reagendar aviso sem registrar consumo |
| US-06 | usuário, ver dias estimados restantes | Planejar compra com confiança explícita |
| US-07 | usuário, comparar ofertas | Entender produto, fonte, data, preço total |
| US-08 | cuidador, acessar perfil autorizado | Cumprir seu papel sem acessar dados alheios |

## Casos extremos que exigem protótipo e teste

- Agenda alterada após uma confirmação; viagem de fuso; mudança de horário do aparelho.
- Notificação bloqueada, atrasada, duplicada ou recebida após edição.
- Confirmação simultânea em dois dispositivos; sem rede; reinstalação durante fila offline.
- Quantidade insuficiente, lote vencido, aquisição parcial, medicamento líquido ou fracionável.
- Produto não localizado em catálogo; código de barras desconhecido; oferta sem frete informado.
- Criança/perfil tutelado e transição de permissões/idade.

**Relações:** `06-design-system.md`, `11-testes.md`.
