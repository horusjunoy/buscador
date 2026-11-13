# Cenários de aceite propostos; NÃO executados. Automatizar por camada e plataforma.
# language: pt
Funcionalidade: Gestão segura de medicamentos, doses e preços
  Como pessoa usuária ou cuidador autorizado
  Quero controlar a rotina e o estoque com precisão
  Para receber lembretes e preparar reposição sem perder rastreabilidade

  Cenário: Dose confirmada gera apenas uma baixa de estoque
    Dado que existe lote com 30 comprimidos do medicamento A
    E existe ocorrência de 1 comprimido atribuída ao perfil autorizado
    Quando confirmo a dose usando o evento E1
    E repito a confirmação com a mesma chave E1
    Então a ocorrência fica tomada_confirmada
    E o saldo físico fica em 29 comprimidos
    E existe somente uma baixa no livro-razão

  Cenário: Sem confirmação não significa dose não tomada
    Dado que existe uma dose programada para 08:00
    Quando o horário e a janela de confirmação passam sem interação
    Então o estado da dose pode se tornar sem_confirmacao
    E não pode ser nao_tomada_declarada
    E o estoque físico permanece inalterado

  Cenário: Usuário declara que não tomou
    Dado que existe uma dose pendente
    Quando seleciono Não tomei
    Então o estado fica nao_tomada_declarada
    E não existe baixa de estoque pela dose

  Cenário: Adiamento não altera prescrição
    Dado que existe uma ocorrência de 08:00
    Quando solicito adiamento do lembrete por 15 minutos
    Então o lembrete fica remarcado para 08:15
    E o plano original conserva seus horários
    E não ocorre baixa de estoque

  Cenário: Registro de dose com estoque zerado
    Dado que o saldo físico é zero
    Quando confirmo explicitamente que tomei a dose
    Então o registro da dose permanece salvo
    E o saldo físico não se torna negativo
    E recebo indicação de conciliação de estoque

  Cenário: Offline não duplica ingestão ao sincronizar
    Dado que estou sem conexão e tenho uma ocorrência pendente
    Quando confirmo a dose offline
    E fecho e reabro o aplicativo
    E reconecto e sincronizo duas vezes
    Então existe apenas uma confirmação remota
    E existe no máximo uma baixa correspondente

  Cenário: Permissão revogada bloqueia pessoa acompanhada
    Dado que um cuidador tinha acesso ao perfil P
    Quando o titular revoga o acesso
    E o cuidador tenta registrar dose no perfil P
    Então o servidor rejeita a operação
    E registra a tentativa sem revelar dados de saúde

  Cenário: Projeção de consumo não altera saldo físico
    Dado que tenho 10 comprimidos físicos
    E o plano prevê consumo futuro diário de 1 comprimido
    Quando consulto a previsão de término
    Então o saldo físico continua 10
    E a previsão aparece separadamente

  Cenário: Abrir oferta não significa comprar ou receber
    Dado que tenho um item na lista de compras
    Quando abro o site da farmácia
    Então o saldo doméstico não muda
    E o item não é marcado como recebido automaticamente

  Cenário: Oferta sem preço final completo não entra como total garantido
    Dado que existe oferta autorizada com preço do item mas frete desconhecido
    Quando comparo por custo total
    Então a oferta informa o custo parcial
    E não afirma ser o menor preço final

  Cenário: Oferta expirou e não pode parecer atual
    Dado que uma oferta possui TTL expirado
    Quando consulto comparações
    Então a oferta aparece expirada ou é atualizada com a fonte
    E não é rotulada como disponibilidade confirmada agora

  Cenário: Comparação de apresentações diferentes requer revisão
    Dado que busco medicamento de concentração X e caixa de 30
    Quando chega uma oferta de concentração Y ou caixa de 60
    Então o sistema sinaliza a diferença
    E não a classifica como correspondência exata

  Cenário: Recebimento aumenta estoque somente com confirmação
    Dado que o item de compra existe e uma oferta foi aberta
    Quando informo lote, validade e quantidade recebida
    E confirmo o recebimento
    Então uma entrada auditável é criada
    E o saldo real aumenta exatamente na unidade correta

  Cenário: Alterar tratamento não altera eventos históricos
    Dado que existe um tratamento com doses já confirmadas
    Quando salvo novos horários para o futuro
    Então uma nova versão do plano é criada
    E as ocorrências históricas mantêm suas versões originais
