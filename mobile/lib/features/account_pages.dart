part of 'pages.dart';

extension _AccountPages on _FeaturePageState {
  Widget family() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Família e cuidado',
        'O acesso a uma pessoa não concede acesso às demais.',
      ),
      action('Adicionar pessoa', Icons.person_add_alt_1, '/profiles/new'),
      const SizedBox(height: 20),
      if (store.persons.isEmpty) missingPerson(),
      for (final person in store.persons)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Design.light,
                    child: Icon(Icons.person_outline, color: Design.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      person['display_name'],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (person['id'] == store.selectedId)
                    const Icon(
                      Icons.check_circle_outline,
                      color: Design.primary,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${person['timezone']} · ${person['is_owner'] == true ? 'Administrado por você' : 'Acesso concedido por permissões'}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      await store.selectPerson(person['id']);
                      showMessage('Perfil selecionado.');
                    },
                    child: const Text('Selecionar pessoa'),
                  ),
                  if (person['is_owner'] == true)
                    TextButton(
                      onPressed: () => go(context, '/family/permissions', {
                        'person': person,
                      }),
                      child: const Text('Gerenciar permissões'),
                    ),
                ],
              ),
            ],
          ),
        ),
    ],
  );

  Widget permissions() {
    final person = args['person'] as Json? ?? store.person;
    if (person == null) return family();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Permissões de cuidado', person['display_name']),
        const Notice(
          'Conceda somente as ações necessárias. Nesta versão, a pessoa convidada deve criar sua própria conta antes da concessão. Convites por e-mail ainda não são enviados.',
        ),
        _PermissionForm(
          store: store,
          person: person,
          onSaved: () {
            redraw();
          },
        ),
        const SectionTitle('Concessões deste perfil'),
        ApiView(
          store: store,
          path: '/v1/persons/${person['id']}/permissions',
          builder: (v) => Column(
            children: [
              for (final permission in rows(v['items']))
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        permission['account_email'],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        permission['active'] == true
                            ? 'Acesso ativo'
                            : 'Acesso revogado',
                      ),
                      Text(
                        (permission['scopes'] as List)
                            .map((s) => _PermissionForm.labels[s] ?? s)
                            .join(', '),
                      ),
                      if (permission['active'] == true)
                        TextButton(
                          onPressed: () async {
                            if (await confirm(
                              context,
                              'Revogar acesso?',
                              'Novas consultas e registros desta pessoa serão negados, inclusive comandos offline que ainda não chegaram ao servidor.',
                            )) {
                              try {
                                await store.api(
                                  '/v1/persons/${person['id']}/permissions/${permission['id']}',
                                  method: 'DELETE',
                                );
                                redraw();
                              } catch (e) {
                                showMessage(humanError(e));
                              }
                            }
                          },
                          child: const Text('Revogar acesso'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget more() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Seu cuidado, do seu jeito',
        'Família, compras, preferências e privacidade.',
      ),
      link(
        'Família e permissões',
        'Escolha quem pode ver e agir em cada perfil',
        Icons.people_outline,
        '/family',
      ),
      link(
        'Tratamentos',
        'Orientações e horários informados',
        Icons.event_note_outlined,
        '/treatments',
      ),
      link(
        'Lista de compras',
        'Reposição com recebimento confirmado',
        Icons.shopping_bag_outlined,
        '/shopping-list',
      ),
      link(
        'Buscar preços',
        'Somente fontes e ofertas verificadas',
        Icons.search,
        '/prices/search',
      ),
      link(
        'Notificações e alertas',
        'Permissões, limites e antecedências',
        Icons.notifications_none,
        '/settings/notifications',
      ),
      link(
        'Sincronização',
        store.outbox.isEmpty && store.mutationKeys.isEmpty
            ? 'Nenhum registro local pendente'
            : '${store.outbox.length + store.mutationKeys.length} registro(s) para conferir',
        Icons.cloud_sync_outlined,
        '/sync',
      ),
      link(
        'Privacidade',
        'Exportação, direitos e informações sobre seus dados',
        Icons.shield_outlined,
        '/settings/privacy',
      ),
      link(
        'Ajuda',
        'Orientações de uso e limites do aplicativo',
        Icons.help_outline,
        '/help',
      ),
      OutlinedButton.icon(
        onPressed: () async {
          if (await confirm(
            context,
            'Sair desta conta?',
            store.outbox.isEmpty && store.mutationKeys.isEmpty
                ? 'A sessão será encerrada e o cache protegido deste dispositivo será removido.'
                : 'Existem registros locais ainda não confirmados pelo servidor. Sair removerá esses registros deste dispositivo. Sincronize antes se quiser preservá-los.',
            action: 'Sair e limpar este dispositivo',
          )) {
            try {
              await store.logout();
            } catch (e) {
              showMessage(
                'Não foi possível revogar a sessão no servidor. Reconecte e tente novamente.',
              );
            }
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('Sair da conta'),
      ),
    ],
  );

  Widget syncPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Sincronização',
        'Um registro local só é definitivo após a confirmação do servidor.',
      ),
      if (store.mutationKeys.isNotEmpty) ...[
        const Notice(
          'Uma alteração pode ter chegado ao servidor, mas a resposta não foi confirmada. Tentar novamente o mesmo formulário reutiliza a chave original. Confira o histórico antes de iniciar outra alteração.',
          warning: true,
        ),
        link(
          'Conferir movimentos',
          'Verifique se a entrada ou saída já foi registrada',
          Icons.history,
          '/inventory/history',
        ),
        link(
          'Conferir medicamentos e tratamentos',
          'Confira o cadastro antes de repetir uma inclusão',
          Icons.medication_outlined,
          '/medications',
        ),
        OutlinedButton(
          onPressed: () async {
            if (await confirm(
              context,
              'Encerrou a conferência?',
              'Encerre esta pendência somente depois de conferir o estado atual no serviço. Uma nova inclusão será uma nova operação explícita.',
              action: 'Conferi o estado no serviço',
            )) {
              try {
                await store.acknowledgeUnknownMutations();
              } catch (e) {
                showMessage(humanError(e));
              }
            }
          },
          child: const Text('Já conferi esta alteração no serviço'),
        ),
        const SizedBox(height: 16),
      ],
      if (store.outbox.isEmpty && store.mutationKeys.isEmpty)
        const EmptyView(
          title: 'Nenhum registro pendente',
          description: 'Os registros enviados foram confirmados pelo serviço.',
          asset: 'completed',
        ),
      for (final command in store.outbox)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusLabel(command['payload']['action']),
              const SizedBox(height: 8),
              Text(
                command['queue_state'] == 'pending'
                    ? 'Aguardando conexão e confirmação.'
                    : 'Precisa de conferência: ${command['detail']}',
              ),
              Text(
                'Horário informado: ${DateTime.parse(command['payload']['occurred_at']).toLocal()}',
              ),
              if (command['queue_state'] == 'conflict')
                TextButton(
                  onPressed: () async {
                    if (await confirm(
                      context,
                      'Encerrar esta pendência local?',
                      'Confira primeiro o histórico e o saldo no servidor. Esta ação remove apenas o comando rejeitado deste dispositivo; não apaga registros aceitos e não altera o estoque.',
                      action: 'Conferi, encerrar pendência',
                    )) {
                      await store.resolveCommand(command['idempotency_key']);
                    }
                  },
                  child: const Text('Já conferi o resultado no histórico'),
                ),
            ],
          ),
        ),
      FilledButton.icon(
        onPressed: store.syncing ? null : store.refresh,
        icon: const Icon(Icons.sync),
        label: const Text('Sincronizar agora'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => go(context, '/doses/history'),
        child: const Text('Conferir histórico de doses'),
      ),
    ],
  );

  Widget notifications() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Notificações e alertas',
        'Os avisos ajudam na organização; nunca confirmam ingestão.',
      ),
      const Notice(
        'Os lembretes usam texto discreto, sem nome de medicamento na tela bloqueada. Permissões, economia de bateria e restrições do aparelho podem impedir ou atrasar a entrega.',
      ),
      const Notice(
        'A agenda local mantém até 60 avisos na próxima semana. Abra o app conectado para atualizar os próximos horários. A entrega em aparelhos físicos ainda precisa de validação.',
      ),
      FilledButton.icon(
        onPressed: () async {
          try {
            final state = await store.reminders.permission();
            await store.reminders.schedule(rows(store.cache['upcoming']));
            showMessage(state);
          } catch (_) {
            showMessage(
              'Não foi possível configurar os lembretes nativos neste dispositivo.',
            );
          }
        },
        icon: const Icon(Icons.notifications_active_outlined),
        label: const Text('Conferir permissão e reagendar'),
      ),
      const SizedBox(height: 24),
      if (store.person?['is_owner'] == true)
        Editor(
          fields: [
            FieldSpec(
              'unconfirmed_minutes',
              'Minutos até indicar sem confirmação',
              initial: '${store.person!['unconfirmed_minutes']}',
              numeric: true,
              helper:
                  'Entre 15 e 1440. Nunca registra não tomada automaticamente.',
            ),
            FieldSpec(
              'expiry_alert_days',
              'Antecedência do alerta de validade (dias)',
              initial: '${store.person!['expiry_alert_days']}',
              numeric: true,
            ),
            FieldSpec(
              'low_stock_days',
              'Antecedência estimada de reposição (dias)',
              initial: '${store.person!['low_stock_days']}',
              numeric: true,
            ),
          ],
          label: 'Salvar preferências',
          submit: (v) async {
            await store.mutate('/v1/persons/${store.selectedId}/preferences', {
              'unconfirmed_minutes': int.parse(v['unconfirmed_minutes']!),
              'expiry_alert_days': int.parse(v['expiry_alert_days']!),
              'low_stock_days': int.parse(v['low_stock_days']!),
            }, method: 'PATCH');
            showMessage('Preferências atualizadas.');
          },
        ),
    ],
  );

  Widget privacy() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Sua privacidade',
        'Transparência sobre o cuidado com dados pessoais e de saúde.',
      ),
      const Panel(
        child: Text(
          'Seus medicamentos, horários e declarações são dados sensíveis quando associados a uma pessoa. O acesso exige autenticação e permissões por perfil e ação. Não há publicidade nem compartilhamento de planos ou histórico com farmácias.\n\nEsta é uma versão local de desenvolvimento para dados sintéticos. A política jurídica, a base legal, o tratamento de menores e os prazos de retenção precisam ser validados antes de um piloto externo. Estas informações não constituem uma política jurídica homologada.\n\nNo dispositivo, o cache e a fila usam armazenamento protegido. Sair remove a cópia local após revogar a sessão. A proteção não elimina os riscos de um dispositivo comprometido.',
        ),
      ),
      FilledButton.icon(
        onPressed: () async {
          if (!await confirm(
            context,
            'Exportar seus registros?',
            'O arquivo conterá dados sensíveis dos perfis que você administra como titular. Salve em um local privado.',
            action: 'Exportar meus registros',
          ))
            return;
          try {
            final exported = await store.api('/v1/privacy/export');
            await store.vault.export(jsonEncode(exported));
            showMessage('Escolha um local privado para salvar seus registros.');
          } catch (e) {
            showMessage(humanError(e));
          }
        },
        icon: const Icon(Icons.download_outlined),
        label: const Text('Exportar meus registros'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () async {
          if (await confirm(
            context,
            'Solicitar exclusão de dados?',
            'Será registrada uma solicitação para análise. A exclusão efetiva e a retenção ainda dependem da política validada. Seus dados não serão apagados imediatamente.',
            action: 'Registrar solicitação',
          )) {
            try {
              await store.api(
                '/v1/privacy/deletion-requests',
                method: 'POST',
                body: {'confirmed': true},
              );
              showMessage(
                'Solicitação registrada para análise. Os dados ainda não foram excluídos.',
              );
            } catch (e) {
              showMessage(humanError(e));
            }
          }
        },
        icon: const Icon(Icons.delete_outline),
        label: const Text('Solicitar exclusão de dados'),
      ),
    ],
  );

  Widget help() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Como podemos ajudar?',
        'Informações para organizar a rotina com clareza.',
      ),
      for (final item in const [
        (
          'O que o aplicativo faz?',
          'Organiza os medicamentos informados, o estoque físico e os horários já orientados. Não diagnostica, prescreve ou recomenda substituições.',
        ),
        (
          'Passei do horário. O que devo fazer?',
          'O aplicativo não orienta compensação de dose. Consulte a orientação já recebida do profissional de saúde. Um horário sem registro permanece sem confirmação.',
        ),
        (
          'Por que o estoque pede conciliação?',
          'O uso pode ser confirmado sem lote ou com saldo insuficiente. O evento é preservado e o saldo não fica negativo artificialmente. Confira o lote físico e o histórico antes de registrar ajustes.',
        ),
        (
          'Como funciona offline?',
          'As informações previamente sincronizadas podem ser consultadas enquanto a sessão local for válida. Registros de dose ficam na fila protegida e precisam de confirmação do servidor. Conflitos aparecem em Mais → Sincronização.',
        ),
        (
          'Por que não vejo preços?',
          'Ainda não existem duas fontes comerciais independentes autorizadas conectadas. Não mostramos ofertas inventadas ou preços regulatórios como ofertas de farmácia.',
        ),
        (
          'Posso confiar que todo lembrete será exibido?',
          'Nenhum sistema de notificações oferece essa garantia. Permissão, bateria e restrições do aparelho influenciam a entrega. A validação em aparelhos físicos ainda é necessária.',
        ),
        (
          'Como obtenho suporte?',
          'Este ambiente ainda não possui um canal externo de atendimento configurado. Registre problemas no checklist de homologação do projeto sem dados pessoais ou clínicos.',
        ),
      ])
        Panel(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              item.$1,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(item.$2),
              ),
            ],
          ),
        ),
    ],
  );
}

class _PermissionForm extends StatefulWidget {
  const _PermissionForm({
    required this.store,
    required this.person,
    required this.onSaved,
  });
  final AppStore store;
  final Json person;
  final VoidCallback onSaved;
  static const labels = {
    'view_medications': 'Visualizar medicamentos e agenda',
    'record_doses': 'Registrar e corrigir doses',
    'manage_stock': 'Gerenciar estoque',
    'manage_plans': 'Editar tratamentos',
    'manage_shopping': 'Gerenciar lista de compras',
  };
  @override
  State<_PermissionForm> createState() => _PermissionFormState();
}

class _PermissionFormState extends State<_PermissionForm> {
  final email = TextEditingController();
  final selected = <String>{};
  bool busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: email,
          decoration: const InputDecoration(
            labelText: 'E-mail da conta cadastrada',
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in _PermissionForm.labels.entries)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(entry.value),
            value: selected.contains(entry.key),
            onChanged: busy
                ? null
                : (v) => setState(() {
                    if (v == true) {
                      selected.add(entry.key);
                    } else {
                      selected.remove(entry.key);
                    }
                  }),
          ),
        if (error != null) Notice(error!, warning: true),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (email.text.trim().isEmpty || selected.isEmpty) {
                    setState(
                      () => error =
                          'Informe uma conta e pelo menos uma permissão.',
                    );
                    return;
                  }
                  if (!await confirm(
                    context,
                    'Conceder estas permissões?',
                    'O acesso será restrito ao perfil ${widget.person['display_name']} e às ações selecionadas.',
                  ))
                    return;
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await widget.store.api(
                      '/v1/persons/${widget.person['id']}/permissions',
                      method: 'POST',
                      body: {
                        'account_email': email.text.trim(),
                        'scopes': selected.toList(),
                      },
                    );
                    widget.onSaved();
                  } catch (e) {
                    if (mounted) setState(() => error = humanError(e));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: const Text('Conceder acesso selecionado'),
        ),
      ],
    ),
  );
}
