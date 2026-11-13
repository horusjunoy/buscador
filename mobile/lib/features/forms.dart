part of 'pages.dart';

String decimal(String value) => value.replaceAll(',', '.');
const weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
List<int> parseDays(String value) {
  if (value.toLowerCase().trim() == 'todos') return List.generate(7, (i) => i);
  return value
      .toLowerCase()
      .split(',')
      .map((d) {
        final text = d.trim().replaceAll('sab', 'sáb');
        final index = weekdays.indexOf(text);
        if (index < 0)
          throw ApiError(
            422,
            'Informe os dias como seg, ter, qua, qui, sex, sáb, dom ou todos.',
          );
        return index;
      })
      .toSet()
      .toList()
    ..sort();
}

List<FieldSpec> lotFields(String unit) => [
  const FieldSpec(
    'quantity',
    'Quantidade física conferida',
    numeric: true,
    helper:
        'Quantidade na unidade abaixo, sem converter caixas automaticamente.',
  ),
  FieldSpec(
    'unit',
    'Unidade',
    initial: unit,
    options: {unit: unitLabels[unit]!},
  ),
  const FieldSpec('lot_code', 'Lote impresso na embalagem'),
  const FieldSpec('expiry_date', 'Validade (AAAA-MM-DD)'),
  const FieldSpec('location', 'Local de armazenamento', optional: true),
];
Json lotBody(Map<String, String> v) => {
  'quantity': decimal(v['quantity']!),
  'unit': v['unit'],
  'lot_code': v['lot_code'],
  'expiry_date': v['expiry_date'],
  'location': v['location'] ?? '',
};

extension _Forms on _FeaturePageState {
  Widget personForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Adicionar pessoa',
        'Use um nome ou apelido. Cada perfil mantém seus próprios registros e permissões.',
      ),
      const Notice(
        'O titular administra os perfis. Compartilhamento com cuidadores exige uma concessão explícita. Use apenas perfis sintéticos neste ambiente.',
      ),
      ApiView(
        store: store,
        path: '/v1/households',
        builder: (value) {
          final own = rows(
            value['items'],
          ).where((h) => h['owner_id'] == store.accountId).toList();
          if (own.isEmpty)
            return const Notice(
              'Somente o titular pode criar perfis na sua própria família.',
              warning: true,
            );
          return Editor(
            fields: [
              FieldSpec(
                'household_id',
                'Família',
                initial: own.first['id'],
                options: {
                  for (final family in own) family['id']: family['name'],
                },
              ),
              const FieldSpec('display_name', 'Nome ou apelido'),
              const FieldSpec(
                'timezone',
                'Fuso horário',
                initial: 'America/Sao_Paulo',
                helper: 'Identificador IANA, por exemplo America/Sao_Paulo.',
              ),
            ],
            label: 'Criar perfil',
            submit: (v) async {
              final person = await store.mutate(
                '/v1/households/${v['household_id']}/persons',
                {'display_name': v['display_name'], 'timezone': v['timezone']},
              );
              await store.selectPerson(person['id']);
              showHome();
            },
          );
        },
      ),
    ],
  );

  Widget medicationForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Adicionar medicamento',
        'Confira os dados da apresentação na embalagem. Nenhuma equivalência é inferida.',
      ),
      Editor(
        fields: const [
          FieldSpec('name', 'Nome do medicamento'),
          FieldSpec('ingredient', 'Princípio ativo'),
          FieldSpec('strength', 'Concentração'),
          FieldSpec(
            'form',
            'Forma farmacêutica',
            options: {
              'comprimido': 'Comprimido',
              'capsula': 'Cápsula',
              'solucao': 'Solução',
              'suspensao': 'Suspensão',
              'pomada': 'Pomada',
              'outra': 'Outra forma informada',
            },
          ),
          FieldSpec('unit', 'Unidade física', options: unitLabels),
          FieldSpec(
            'pack_quantity',
            'Quantidade na apresentação',
            numeric: true,
          ),
          FieldSpec(
            'gtin',
            'GTIN/código de barras (opcional)',
            optional: true,
            numeric: true,
          ),
        ],
        confirmation:
            'Conferi princípio ativo, concentração, forma, quantidade e unidade desta apresentação.',
        label: 'Salvar apresentação',
        submit: (v) async {
          final result = await store
              .mutate('/v1/persons/${store.selectedId}/medications', {
                'name': v['name'],
                'ingredient': v['ingredient'],
                'strength': v['strength'],
                'form': v['form'],
                'unit': v['unit'],
                'pack_quantity': decimal(v['pack_quantity']!),
                if (v['gtin']!.isNotEmpty) 'gtin': v['gtin'],
                'presentation_confirmed': true,
              });
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/medications/detail',
            arguments: {'medication': result['medication']},
          );
        },
      ),
    ],
  );

  Widget lotForm() {
    final med = args['medication'] as Json?;
    if (med == null) return medications();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Entrada de lote', identity(med)),
        Editor(
          fields: lotFields(med['unit']),
          confirmation: 'Conferi a quantidade física, o lote e a validade.',
          label: 'Registrar entrada',
          submit: (v) async {
            await store.mutate('/v1/medications/${med['id']}/lots', lotBody(v));
            if (mounted) done();
          },
        ),
      ],
    );
  }

  Widget movementForm() {
    final lot = args['lot'] as Json?;
    if (lot == null) return inventory();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          'Registrar movimento',
          'Lote ${lot['lot_code']} · Saldo físico ${number(lot['balance'])} ${unitLabels[lot['unit']]}',
        ),
        const Notice(
          'Nenhum saldo é substituído diretamente. O movimento ficará no histórico; erros são corrigidos com estorno.',
        ),
        Editor(
          fields: [
            const FieldSpec(
              'reason',
              'Tipo de movimento',
              options: {
                'entrada_compra': 'Entrada por recebimento',
                'entrada_ajuste': 'Entrada por conferência',
                'saida_manual': 'Saída manual',
                'descarte': 'Descarte',
                'ajuste_auditado': 'Ajuste assinado por conferência',
              },
            ),
            const FieldSpec(
              'quantity',
              'Quantidade do movimento',
              numeric: true,
              helper:
                  'Para ajuste assinado: positivo acrescenta; negativo retira. Não informe o saldo final.',
            ),
            FieldSpec(
              'unit',
              'Unidade',
              initial: lot['unit'],
              options: {lot['unit']: unitLabels[lot['unit']]!},
            ),
          ],
          confirmation:
              'Conferi o movimento e quero registrá-lo no livro de estoque.',
          label: 'Confirmar movimento',
          submit: (v) async {
            await store.mutate('/v1/stock-batches/${lot['id']}/movements', {
              'quantity': decimal(v['quantity']!),
              'unit': v['unit'],
              'reason': v['reason'],
              'confirmed': true,
            });
            if (mounted) done();
          },
        ),
      ],
    );
  }

  Widget planForm() {
    final med = args['medication'] as Json?;
    if (med == null) return medications();
    final plan = args['plan'] as Json?;
    final version = plan?['active_version'] as Json?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          plan == null
              ? 'Registrar tratamento'
              : 'Revisar tratamento informado',
          identity(med),
        ),
        const Notice(
          'Copie somente a orientação que você já recebeu. O sistema organiza horários; não avalia a adequação clínica da posologia.',
        ),
        Editor(
          fields: [
            FieldSpec(
              'dose_quantity',
              'Quantidade por horário informado',
              initial: version == null ? '' : number(version['dose_quantity']),
              numeric: true,
            ),
            FieldSpec(
              'unit',
              'Unidade da dose',
              initial: med['unit'],
              options: {med['unit']: unitLabels[med['unit']]!},
            ),
            FieldSpec(
              'times',
              'Horários informados (HH:MM)',
              initial: version == null
                  ? ''
                  : (version['times'] as List).join(', '),
              helper:
                  'Separe horários por vírgula. Use somente os horários orientados.',
            ),
            FieldSpec(
              'weekdays',
              'Dias da semana',
              initial: version == null
                  ? ''
                  : (version['weekdays'] as List)
                        .map((d) => weekdays[d as int])
                        .join(', '),
              helper:
                  'Informe todos ou dias separados por vírgula: seg, ter, qua, qui, sex, sáb, dom.',
            ),
            FieldSpec(
              'timezone',
              'Fuso da agenda',
              initial:
                  version?['timezone'] ??
                  store.person?['timezone'] ??
                  'America/Sao_Paulo',
            ),
            FieldSpec(
              'start_date',
              plan == null
                  ? 'Data inicial (AAAA-MM-DD)'
                  : 'Data de vigência da revisão (hoje)',
              initial: version == null || plan != null
                  ? isoDay(DateTime.now())
                  : version['start_date'],
            ),
            FieldSpec(
              'end_date',
              'Data final (opcional, AAAA-MM-DD)',
              initial: version?['end_date'] ?? '',
              optional: true,
              helper: 'Deixe vazio para uso contínuo conforme orientação.',
            ),
            FieldSpec(
              'source_kind',
              'Origem da informação',
              initial: version?['source_kind'] ?? '',
              options: {
                'orientacao_informada': 'Orientação recebida e informada',
                'receita_informada': 'Receita informada pelo responsável',
                'responsavel_informou': 'Informação do responsável',
              },
            ),
            FieldSpec(
              'instructions',
              'Observações da orientação (opcional)',
              initial: version?['instructions'] ?? '',
              optional: true,
            ),
          ],
          confirmation:
              'Esta quantidade e estes horários correspondem à orientação que recebi. Quero conferir a prévia.',
          label: 'Conferir agenda antes de salvar',
          submit: (v) async {
            final data = {
              'dose_quantity': decimal(v['dose_quantity']!),
              'unit': v['unit'],
              'times': v['times']!.split(',').map((t) => t.trim()).toList(),
              'weekdays': parseDays(v['weekdays']!),
              'timezone': v['timezone'],
              'start_date': v['start_date'],
              if (v['end_date']!.isNotEmpty) 'end_date': v['end_date'],
              'source_kind': v['source_kind'],
              'instructions': v['instructions'],
              'instructions_confirmed': true,
            };
            final result = await store.api(
              '/v1/plans/preview',
              method: 'POST',
              body: data,
            );
            if (!mounted) return;
            go(context, '/treatments/preview', {
              'medication': med,
              'plan': plan,
              'input': data,
              'preview': result,
            });
          },
        ),
      ],
    );
  }

  Widget preview() {
    final med = args['medication'] as Json?;
    final input = args['input'] as Json?;
    if (med == null || input == null) return treatments();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Conferir os próximos horários', identity(med)),
        Notice(
          '${number(input['dose_quantity'])} ${unitLabels[input['unit']]} por horário informado · ${input['timezone']}',
        ),
        for (final occurrence in rows(args['preview']?['items']))
          Panel(
            padding: 14,
            child: Row(
              children: [
                const Icon(Icons.schedule, color: Design.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${occurrence['local_date']} · ${occurrence['scheduled_local'].toString().substring(11, 16)} · ${occurrence['timezone']}',
                  ),
                ),
              ],
            ),
          ),
        Notice(
          args['preview']?['dst_policy'] ??
              'Revise os horários locais antes de confirmar.',
        ),
        FilledButton.icon(
          onPressed: () async {
            if (!await confirm(
              context,
              'Registrar esta orientação?',
              'Confirme que os dados e a prévia correspondem à orientação recebida. Salvar não confirma nenhuma dose como tomada.',
              action: 'Registrar tratamento',
            ))
              return;
            try {
              final plan = args['plan'] as Json?;
              await store.mutate(
                plan == null
                    ? '/v1/medications/${med['id']}/plans'
                    : '/v1/plans/${plan['id']}',
                {...input, if (plan != null) 'version': plan['revision']},
                method: plan == null ? 'POST' : 'PATCH',
              );
              if (!mounted) return;
              showTreatments();
            } catch (e) {
              showMessage(humanError(e));
            }
          },
          icon: const Icon(Icons.check),
          label: const Text('Confirmar tratamento informado'),
        ),
      ],
    );
  }

  Widget doseConfirmation() {
    final dose = args['dose'] as Json?;
    if (dose == null) return agenda();
    final correction = args['correction'] as Json?;
    final med = Map<String, dynamic>.from(dose['medication']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          correction == null
              ? 'Registrar o que aconteceu'
              : 'Corrigir a declaração',
          identity(med),
        ),
        Notice(
          '${dose['local_date']} · ${clock(dose)} · ${number(dose['dose_quantity'])} ${unitLabels[dose['unit']]} · ${dose['timezone']}',
        ),
        if (correction != null)
          const Notice(
            'Correções exigem conexão para conferir o último evento. O evento anterior é preservado e haverá estorno de estoque quando aplicável.',
            warning: true,
          ),
        FutureBuilder<Json>(
          future: store
              .fetch('/v1/medications/${med['id']}/lots')
              .catchError((_) => {'items': []}),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final stock = rows(snapshot.data!['items'])
                .where(
                  (l) =>
                      l['expired'] != true &&
                      double.parse(l['balance'].toString()) > 0,
                )
                .toList();
            return Editor(
              fields: [
                const FieldSpec(
                  'action',
                  'O que você quer registrar?',
                  options: {
                    'tomada_confirmada': 'Tomei — confirmar uso',
                    'nao_tomada_declarada': 'Não tomei — declarar',
                    'adiar15': 'Adiar lembrete em 15 minutos',
                    'adiar30': 'Adiar lembrete em 30 minutos',
                  },
                ),
                FieldSpec(
                  'occurred_at',
                  'Quando aconteceu (horário deste dispositivo)',
                  initial: DateTime.now().toString().substring(0, 16),
                  helper:
                      'AAAA-MM-DD HH:MM. Confira se está registrando um evento passado.',
                ),
                FieldSpec(
                  'lot_id',
                  'Lote físico usado (apenas se tomou)',
                  initial: 'none',
                  options: {
                    'none': 'Não alocar lote — conferir estoque depois',
                    for (final lot in stock)
                      lot['id']:
                          '${lot['lot_code']} · ${number(lot['balance'])} · validade ${lot['expiry_date']}',
                  },
                  helper:
                      'Sem lote válido ou sem saldo, o uso fica registrado e o estoque pede conciliação.',
                ),
              ],
              confirmation:
                  'Conferi esta declaração e quero registrá-la para a pessoa selecionada.',
              label: correction == null
                  ? 'Confirmar meu registro'
                  : 'Confirmar correção auditável',
              submit: (v) async {
                final kind = v['action']!.startsWith('adiar')
                    ? 'adiada'
                    : v['action'];
                final payload = {
                  'action': kind,
                  'version': dose['revision'],
                  'client_event_id': newId(),
                  'occurred_at': DateTime.parse(
                    v['occurred_at']!,
                  ).toUtc().toIso8601String(),
                  'confirmed': true,
                  if (kind == 'adiada')
                    'snooze_minutes': v['action'] == 'adiar15' ? 15 : 30,
                  if (kind == 'tomada_confirmada' && v['lot_id'] != 'none')
                    'lot_id': v['lot_id'],
                };
                String message;
                if (correction != null) {
                  await store.mutate(
                    '/v1/dose-occurrences/${dose['id']}/corrections',
                    {...payload, 'corrects_event_id': correction['id']},
                  );
                  message = 'Correção registrada com histórico preservado.';
                } else {
                  message = await store.recordDose(dose, payload);
                }
                if (!mounted) return;
                showMessage(message);
                done();
              },
            );
          },
        ),
      ],
    );
  }

  Widget shoppingForm() {
    if (store.medications.isEmpty) return medications();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          'Adicionar à lista',
          'Esta ação organiza a compra; não altera seu estoque.',
        ),
        Editor(
          fields: [
            FieldSpec(
              'medication_id',
              'Medicamento',
              initial: args['medication']?['id'] ?? '',
              options: {
                for (final med in store.medications) med['id']: identity(med),
              },
            ),
            const FieldSpec(
              'quantity',
              'Quantidade desejada na unidade física',
              numeric: true,
              helper:
                  'Não convertemos caixas, frascos ou apresentações automaticamente.',
            ),
          ],
          label: 'Adicionar à lista',
          submit: (v) async {
            final med = store.medications.firstWhere(
              (m) => m['id'] == v['medication_id'],
            );
            await store.mutate('/v1/shopping-items', {
              'medication_id': med['id'],
              'quantity': decimal(v['quantity']!),
              'unit': med['unit'],
            });
            if (mounted) done();
          },
        ),
      ],
    );
  }

  Widget receiveForm() {
    final item = args['item'] as Json?;
    if (item == null) return shopping();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          'Confirmar recebimento',
          identity(Map<String, dynamic>.from(item['medication'])),
        ),
        const Notice(
          'Informe o que foi efetivamente recebido, mesmo que seja diferente da quantidade planejada. Abrir uma oferta não confirma compra ou entrega.',
        ),
        Editor(
          fields: lotFields(item['unit']),
          confirmation:
              'Recebi e conferi fisicamente esta quantidade, lote e validade.',
          label: 'Confirmar recebimento e entrada',
          submit: (v) async {
            await store.mutate('/v1/shopping-items/${item['id']}/receive', {
              ...lotBody(v),
              'version': item['revision'],
              'received_confirmed': true,
            });
            if (mounted) done();
          },
        ),
      ],
    );
  }
}
