import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/design.dart';
import '../core/store.dart';
import 'editor.dart';
import 'workspace.dart';
part 'forms.dart';
part 'account_pages.dart';

const unitLabels = {
  'comprimido': 'Comprimido(s)',
  'capsula': 'Cápsula(s)',
  'mL': 'mL',
  'gota': 'Gota(s)',
  'dose': 'Dose(s)',
  'frasco': 'Frasco(s)',
  'unidade': 'Unidade(s)',
};
String number(dynamic value) {
  final text = value.toString();
  return text.contains('.')
      ? text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : text;
}

String clock(Json d) {
  final local = d['scheduled_local'] as String?;
  return local != null
      ? local.substring(11, 16)
      : DateTime.parse(
          d['scheduled_at'],
        ).toLocal().toString().substring(11, 16);
}

String identity(Json med) => '${med['name']} · ${med['strength']}';

class FeaturePage extends StatefulWidget {
  const FeaturePage({
    super.key,
    required this.store,
    required this.route,
    this.args,
  });
  final AppStore store;
  final String route;
  final Json? args;
  @override
  State<FeaturePage> createState() => _FeaturePageState();
}

class _FeaturePageState extends State<FeaturePage> {
  AppStore get store => widget.store;
  Json get args => widget.args ?? {};
  String search = '';
  DateTime day = DateTime.now();
  void redraw() {
    if (mounted) setState(() {});
  }

  void showMessage(String text) {
    if (mounted) toast(context, text);
  }

  void openPage(String route, [Json? value]) {
    if (mounted) go(context, route, value);
  }

  void replacePage(String route, Json value) {
    if (mounted)
      Navigator.pushReplacementNamed(context, route, arguments: value);
  }

  void showTreatments() {
    if (mounted)
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/treatments',
        (r) => r.isFirst,
      );
  }

  void done() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      go(context, '/home');
    }
  }

  void showHome() {
    if (mounted)
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => r.isFirst);
  }

  Widget heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(subtitle),
      ],
    ),
  );
  Widget link(
    String title,
    String subtitle,
    IconData icon,
    String route, [
    Json? value,
  ]) => Panel(
    padding: 4,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Design.light,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Design.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => go(context, route, value),
    ),
  );
  Widget action(String label, IconData icon, String route, [Json? value]) =>
      FilledButton.icon(
        onPressed: () => go(context, route, value),
        icon: Icon(icon),
        label: Text(label),
      );
  Widget missingPerson() => EmptyView(
    title: 'De quem vamos cuidar?',
    description:
        'Crie um perfil para organizar medicamentos e rotina com permissões próprias.',
    asset: 'family',
    action: action(
      'Criar primeiro perfil',
      Icons.person_add_alt_1,
      '/profiles/new',
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (store.person == null &&
        ![
          '/profiles/new',
          '/family',
          '/more',
          '/settings/privacy',
          '/help',
          '/home',
          '/sync',
          '/profiles/select',
        ].contains(widget.route))
      return missingPerson();
    return switch (widget.route) {
      '/home' => home(),
      '/profiles/new' => personForm(),
      '/profiles/select' => family(),
      '/medications' => medications(),
      '/medications/new' => medicationForm(),
      '/medications/catalog' => catalog(),
      '/medications/scan' => scan(),
      '/medications/detail' => medicationDetail(),
      '/agenda' => agenda(),
      '/doses/detail' => doseDetail(),
      '/doses/confirm' => doseConfirmation(),
      '/doses/history' => history(),
      '/treatments' => treatments(),
      '/treatments/edit' => planForm(),
      '/treatments/preview' => preview(),
      '/inventory' => inventory(),
      '/inventory/lots' => lots(),
      '/inventory/lots/new' => lotForm(),
      '/inventory/movements/new' => movementForm(),
      '/inventory/history' => stockHistory(),
      '/alerts' => alerts(),
      '/shopping-list' => shopping(),
      '/shopping-list/new' => shoppingForm(),
      '/shopping-list/receive' => receiveForm(),
      '/prices/search' => prices(),
      '/prices/results' || '/prices/offers/detail' => noOffers(),
      '/family' => family(),
      '/family/permissions' => permissions(),
      '/more' => more(),
      '/sync' => syncPage(),
      '/settings/notifications' => notifications(),
      '/settings/privacy' => privacy(),
      '/help' => help(),
      _ => EmptyView(
        title: 'Página não encontrada',
        description: 'Volte ao início para continuar com segurança.',
        action: action('Ir para o início', Icons.home_outlined, '/home'),
      ),
    };
  }

  Widget home() {
    final confirmed = store.doses
        .where((d) => d['status'] == 'tomada_confirmada')
        .length;
    final awaiting = store.doses
        .where(
          (d) =>
              ['pendente', 'sem_confirmacao', 'adiada'].contains(d['status']),
        )
        .length;
    final next = store.doses
        .where(
          (d) => ![
            'tomada_confirmada',
            'nao_tomada_declarada',
            'cancelada',
          ].contains(d['status']),
        )
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'UM DIA DE CADA VEZ',
                    style: TextStyle(
                      letterSpacing: 1.7,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Design.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    store.person == null
                        ? 'Seu cuidado,\nmais organizado.'
                        : 'Olá, ${store.person!['display_name']}',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Vamos acompanhar sua rotina de hoje.'),
                ],
              ),
            ),
            if (MediaQuery.sizeOf(context).width > 420)
              Image.asset(
                'assets/illustrations/medication-bottle-preview.png',
                height: 120,
                width: 120,
                excludeFromSemantics: true,
              ),
          ],
        ),
        const SizedBox(height: 28),
        if (store.person == null)
          missingPerson()
        else ...[
          Panel(
            color: Design.light,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.fact_check_outlined,
                      color: Design.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Seus registros de hoje',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => go(context, '/agenda'),
                      child: const Text('Ver agenda'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$confirmed de ${store.doses.length}',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: Design.dark,
                  ),
                ),
                const Text('doses com uso confirmado por você ou cuidador'),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: store.doses.isEmpty
                        ? 0
                        : confirmed / store.doses.length,
                    minHeight: 10,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$awaiting aguardando registro · Ausência de registro não significa não tomada.',
                  style: const TextStyle(fontSize: 12, color: Design.dark),
                ),
              ],
            ),
          ),
          if (next != null) ...[
            const SectionTitle('Sua próxima confirmação'),
            doseCard(next),
          ] else
            EmptyView(
              title: store.doses.isEmpty
                  ? 'Sua agenda começa aqui'
                  : 'Registros de hoje organizados',
              description: store.doses.isEmpty
                  ? 'Cadastre um medicamento e os horários que já foram orientados.'
                  : 'Você pode conferir todos os eventos no histórico.',
              asset: store.doses.isEmpty ? 'daily-reminder' : 'completed',
              action: action(
                store.medications.isEmpty
                    ? 'Adicionar medicamento'
                    : 'Ver tratamentos',
                Icons.add,
                store.medications.isEmpty ? '/medications/new' : '/treatments',
              ),
            ),
          if (store.alerts.isNotEmpty)
            link(
              '${store.alerts.length} alerta(s) para conferir',
              'Estoque e validades merecem atenção',
              Icons.warning_amber_rounded,
              '/alerts',
            ),
          const SectionTitle('Ações rápidas'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              quick('Adicionar', Icons.add, '/medications/new'),
              quick('Estoque', Icons.inventory_2_outlined, '/inventory'),
              quick('Tratamentos', Icons.event_note_outlined, '/treatments'),
              quick('Compras', Icons.shopping_bag_outlined, '/shopping-list'),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Panel(
          child: Row(
            children: [
              Image.asset(
                'assets/illustrations/best-price-preview.png',
                width: 72,
                height: 72,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Organize sua próxima compra',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Compare somente ofertas verificadas. Fontes comerciais ainda indisponíveis.',
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => go(context, '/prices/search'),
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar preços'),
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

  Widget quick(String label, IconData icon, String route) => SizedBox(
    width: 140,
    child: OutlinedButton(
      onPressed: () => go(context, route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 10),
            Text(label),
          ],
        ),
      ),
    ),
  );

  Widget doseCard(Json dose) {
    final waiting = store.pending(dose['id']);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                clock(dose),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: Design.dark,
                ),
              ),
              StatusLabel(waiting ? 'pending_sync' : dose['status']),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            identity(Map<String, dynamic>.from(dose['medication'])),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(
            '${number(dose['dose_quantity'])} ${unitLabels[dose['unit']]} · ${dose['timezone']}',
          ),
          if (dose['stock_reconciliation_required'] == true) ...[
            const SizedBox(height: 10),
            const Notice(
              'Uso registrado. Estoque aguardando conciliação.',
              warning: true,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (![
                    'tomada_confirmada',
                    'nao_tomada_declarada',
                    'cancelada',
                  ].contains(dose['status']) &&
                  store.scope('record_doses'))
                FilledButton.icon(
                  onPressed: waiting
                      ? null
                      : () => go(context, '/doses/confirm', {'dose': dose}),
                  icon: const Icon(Icons.check),
                  label: const Text('Registrar dose'),
                ),
              OutlinedButton(
                onPressed: () => go(context, '/doses/detail', {'dose': dose}),
                child: const Text('Ver detalhes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget medications() {
    final items = store.medications
        .where(
          (m) => '${m['name']} ${m['ingredient']}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          'Meus medicamentos',
          'Apresentações confirmadas por você, organizadas por perfil.',
        ),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar nos meus medicamentos',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (store.scope('manage_plans'))
              action('Adicionar medicamento', Icons.add, '/medications/new'),
            OutlinedButton.icon(
              onPressed: () => go(context, '/medications/catalog'),
              icon: const Icon(Icons.search),
              label: const Text('Consultar catálogo'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (items.isEmpty)
          const EmptyView(
            title: 'Nenhum medicamento por aqui',
            description:
                'Adicione a apresentação exatamente como está na embalagem. Não fazemos substituições automáticas.',
          ),
        for (final med in items)
          link(
            identity(med),
            '${med['form']} · ${number(med['pack_quantity'])} ${unitLabels[med['unit']]}',
            Icons.medication_outlined,
            '/medications/detail',
            {'medication': med},
          ),
      ],
    );
  }

  Widget medicationDetail() {
    final med = args['medication'] as Json?;
    if (med == null) return medications();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          med['name'],
          'Conheça o cadastro e acompanhe os registros desta apresentação.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/illustrations/medication-bottle-preview.png',
                height: 100,
                excludeFromSemantics: true,
              ),
              Text(
                med['strength'],
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Princípio ativo: ${med['ingredient']}'),
              Text('Forma: ${med['form']}'),
              Text(
                'Embalagem: ${number(med['pack_quantity'])} ${unitLabels[med['unit']]}',
              ),
              if (med['gtin'] != null) Text('GTIN informado: ${med['gtin']}'),
              const SizedBox(height: 16),
              const Notice(
                'Cadastro manual confirmado pelo responsável. Não validado em catálogo regulatório externo.',
              ),
            ],
          ),
        ),
        link(
          'Lotes e validade',
          'Saldo físico e histórico deste medicamento',
          Icons.inventory_2_outlined,
          '/inventory/lots',
          {'medication': med},
        ),
        if (store.scope('manage_plans'))
          link(
            'Registrar tratamento',
            'Use somente a orientação já recebida',
            Icons.calendar_month_outlined,
            '/treatments/edit',
            {'medication': med},
          ),
        if (store.scope('manage_shopping'))
          link(
            'Adicionar à lista de compras',
            'O estoque só muda após recebimento confirmado',
            Icons.shopping_bag_outlined,
            '/shopping-list/new',
            {'medication': med},
          ),
      ],
    );
  }

  Widget catalog() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Consultar catálogo',
        'Confirme sempre concentração, forma e quantidade da apresentação.',
      ),
      EmptyView(
        title: 'Catálogo externo indisponível',
        description:
            'Ainda não há uma fonte autorizada conectada. O cadastro manual continua disponível.',
        asset: 'no-offers',
        action: action(
          'Cadastrar manualmente',
          Icons.edit_outlined,
          '/medications/new',
        ),
      ),
      link(
        'Consultar por código de barras',
        'Confira o GTIN impresso na embalagem',
        Icons.qr_code_scanner,
        '/medications/scan',
      ),
    ],
  );
  Widget scan() => Column(
    children: [
      heading(
        'Código da embalagem',
        'Leitura assistida depende de câmera e catálogo homologados.',
      ),
      const Notice(
        'A captura por câmera não está habilitada neste ciclo. Você pode informar o GTIN manualmente; sem catálogo autorizado não confirmaremos correspondência.',
      ),
      Editor(
        fields: const [
          FieldSpec('gtin', 'GTIN impresso na embalagem', numeric: true),
        ],
        label: 'Consultar código',
        submit: (v) async {
          await store.api(
            '/v1/catalog/presentations?q=${Uri.encodeComponent(v['gtin']!)}',
          );
          if (!mounted) return;
          toast(
            context,
            'Não há catálogo autorizado. Confira a embalagem e use o cadastro manual.',
          );
        },
      ),
      action('Adicionar manualmente', Icons.edit, '/medications/new'),
    ],
  );

  Widget agenda() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Sua agenda',
        'Horários informados, registros explícitos e histórico preservado.',
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final chosen = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (chosen != null) setState(() => day = chosen);
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(isoDay(day)),
          ),
          TextButton(
            onPressed: () => go(context, '/doses/history'),
            child: const Text('Histórico de registros'),
          ),
          TextButton(
            onPressed: () => go(context, '/treatments'),
            child: const Text('Tratamentos'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      ApiView(
        store: store,
        path:
            '/v1/persons/${store.selectedId}/dose-occurrences?start=${isoDay(day)}&end=${isoDay(day)}',
        builder: (value) {
          final list = rows(value['items']);
          return list.isEmpty
              ? const EmptyView(
                  title: 'Nenhuma dose neste dia',
                  description:
                      'Seus horários aparecem aqui depois de cadastrar um tratamento.',
                  asset: 'daily-reminder',
                )
              : Column(children: list.map(doseCard).toList());
        },
      ),
    ],
  );
  Widget doseDetail() {
    final dose = args['dose'] as Json?;
    if (dose == null) return agenda();
    return ApiView(
      store: store,
      path: '/v1/dose-occurrences/${dose['id']}',
      builder: (current) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(
            'Detalhe da dose',
            'Uso, autoria e horários permanecem no histórico.',
          ),
          doseCard(current),
          if (store.scope('record_doses') && rows(current['events']).isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => go(context, '/doses/confirm', {
                'dose': current,
                'correction': rows(current['events']).last,
              }),
              icon: const Icon(Icons.edit_note),
              label: const Text('Corrigir último registro'),
            ),
          const SectionTitle('Histórico desta dose'),
          if (rows(current['events']).isEmpty)
            const Notice(
              'Ainda não há declaração de uso. A ausência de confirmação não significa que a dose não foi tomada.',
            ),
          for (final event in rows(current['events']))
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusLabel(event['action']),
                  const SizedBox(height: 8),
                  Text(
                    'Informado em ${DateTime.parse(event['occurred_at']).toLocal()}',
                  ),
                  Text(
                    'Registrado por pessoa autorizada em ${DateTime.parse(event['created_at']).toLocal()}',
                  ),
                  if (event['supersedes_id'] != null)
                    const Text('Correção vinculada ao evento anterior.'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget history() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Histórico de doses',
        'Consulte eventos e corrija declarações preservando a trilha.',
      ),
      ApiView(
        store: store,
        path:
            '/v1/persons/${store.selectedId}/dose-occurrences?start=${isoDay(DateTime.now().subtract(const Duration(days: 30)))}&end=${isoDay(DateTime.now())}',
        builder: (v) {
          final list = rows(v['items']).reversed.toList();
          return list.isEmpty
              ? const EmptyView(
                  title: 'Sem registros neste período',
                  description:
                      'O histórico dos últimos 30 dias aparecerá aqui.',
                  asset: 'daily-reminder',
                )
              : Column(
                  children: list
                      .map(
                        (d) => link(
                          '${d['local_date']} · ${clock(d)}',
                          '${identity(Map<String, dynamic>.from(d['medication']))} · ${StatusLabel.labels[d['status']] ?? d['status']}',
                          Icons.history,
                          '/doses/detail',
                          {'dose': d},
                        ),
                      )
                      .toList(),
                );
        },
      ),
    ],
  );
  Widget treatments() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Tratamentos',
        'Orientações cadastradas pelo responsável. Nenhuma dose é sugerida pelo sistema.',
      ),
      if (store.plans.isEmpty)
        EmptyView(
          title: 'Organize os horários informados',
          description:
              'Selecione um medicamento e registre a orientação que já recebeu.',
          asset: 'daily-reminder',
          action: action(
            'Escolher medicamento',
            Icons.medication_outlined,
            '/medications',
          ),
        ),
      for (final plan in store.plans)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                identity(Map<String, dynamic>.from(plan['medication'])),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${number(plan['active_version']['dose_quantity'])} ${unitLabels[plan['active_version']['unit']]} · ${(plan['active_version']['times'] as List).join(', ')}',
              ),
              Text(
                'Estado: ${plan['status']} · Versão ${plan['revision']} · ${plan['active_version']['timezone']}',
              ),
              const SizedBox(height: 14),
              if (store.scope('manage_plans'))
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: () => go(context, '/treatments/edit', {
                        'medication': plan['medication'],
                        'plan': plan,
                      }),
                      child: const Text('Editar orientação informada'),
                    ),
                    if (plan['status'] == 'ativo')
                      TextButton(
                        onPressed: () async {
                          if (await confirm(
                            context,
                            'Suspender este plano?',
                            'Confirme que a suspensão reflete a orientação recebida. Doses futuras serão canceladas; o histórico será preservado.',
                            action: 'Registrar suspensão',
                          )) {
                            try {
                              await store
                                  .mutate('/v1/plans/${plan['id']}/status', {
                                    'version': plan['revision'],
                                    'status': 'suspenso',
                                    'confirmed': true,
                                  });
                            } catch (e) {
                              showMessage(humanError(e));
                            }
                          }
                        },
                        child: const Text('Registrar suspensão'),
                      ),
                  ],
                ),
            ],
          ),
        ),
    ],
  );

  Widget inventory() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Seu estoque',
        'O saldo físico vem de movimentos registrados. A previsão é uma estimativa separada.',
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () => go(context, '/inventory/history'),
            icon: const Icon(Icons.history),
            label: const Text('Livro de movimentos'),
          ),
          OutlinedButton.icon(
            onPressed: () => go(context, '/shopping-list'),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Lista de compras'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (store.inventory.isEmpty)
        EmptyView(
          title: 'Seu armário está vazio',
          description:
              'Comece cadastrando um medicamento e a quantidade que possui.',
          asset: 'stock-box',
          action: action(
            'Adicionar medicamento',
            Icons.add,
            '/medications/new',
          ),
        ),
      for (final item in store.inventory)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                identity(Map<String, dynamic>.from(item['medication'])),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 28,
                runSpacing: 12,
                children: [
                  metric(number(item['physical_balance']), 'Saldo físico'),
                  metric(number(item['eligible_balance']), 'Saldo não vencido'),
                  metric(
                    item['days_remaining'] == null
                        ? '—'
                        : '${item['days_remaining']} dias',
                    'Previsão de reposição',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${number(item['expired_balance'])} vencido(s) · ${unitLabels[item['medication']['unit']]}',
              ),
              Text(
                'Previsão: ${item['quality'] == 'sem_plano' ? 'sem plano para estimar' : 'consumo planejado por até ${item['horizon_days']} dias'}.',
              ),
              if (item['depletion_date'] != null)
                Text(
                  'Primeira demanda sem cobertura estimada: ${item['depletion_date']}',
                ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => go(context, '/inventory/lots', {
                  'medication': item['medication'],
                }),
                child: const Text('Conferir lotes e movimentar'),
              ),
            ],
          ),
        ),
      if (store.inventory.isNotEmpty)
        const Notice(
          'Estimativa considera horários cadastrados e vencimentos. Não confirma uso e não altera o estoque físico.',
        ),
    ],
  );
  Widget metric(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Design.dark,
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
  Widget lots() {
    final med = args['medication'] as Json?;
    if (med == null) return medications();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Lotes e validade', identity(med)),
        if (store.scope('manage_stock'))
          action(
            'Registrar entrada de lote',
            Icons.add,
            '/inventory/lots/new',
            {'medication': med},
          ),
        const SizedBox(height: 20),
        ApiView(
          store: store,
          path: '/v1/medications/${med['id']}/lots',
          builder: (v) {
            final list = rows(v['items']);
            return Column(
              children: [
                if (list.isEmpty)
                  const EmptyView(
                    title: 'Ainda sem lote cadastrado',
                    description:
                        'Informe a quantidade real, a unidade, o lote e a validade.',
                    asset: 'stock-box',
                  ),
                for (final lot in list)
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Lote ${lot['lot_code']}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${number(lot['balance'])} ${unitLabels[lot['unit']]} · Validade ${lot['expiry_date']}',
                        ),
                        if (lot['location'] != '')
                          Text('Local: ${lot['location']}'),
                        if (lot['expired'] == true)
                          const Notice(
                            'Lote vencido. Está no saldo físico e fora da projeção de uso.',
                            warning: true,
                          ),
                        if (store.scope('manage_stock')) ...[
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: () => go(
                              context,
                              '/inventory/movements/new',
                              {'medication': med, 'lot': lot},
                            ),
                            child: const Text('Registrar movimento'),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget stockHistory() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Livro de movimentos',
        'Entradas, saídas e correções preservam autoria e histórico.',
      ),
      ApiView(
        store: store,
        path: '/v1/persons/${store.selectedId}/inventory/history',
        builder: (v) {
          final list = rows(v['items']);
          return Column(
            children: [
              if (list.isEmpty)
                const EmptyView(
                  title: 'Nenhum movimento registrado',
                  description:
                      'Os movimentos aparecerão após cadastrar um lote.',
                  asset: 'stock-box',
                ),
              for (final entry in list)
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${number(entry['delta'])} ${unitLabels[entry['unit']]}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${entry['reason']} · ${DateTime.parse(entry['created_at']).toLocal()}',
                      ),
                      if (entry['reversal_of'] != null)
                        const Text(
                          'Movimento compensatório de um registro anterior.',
                        ),
                      if (entry['related_event_id'] == null &&
                          entry['reversal_of'] == null &&
                          store.scope('manage_stock'))
                        TextButton(
                          onPressed: () async {
                            if (await confirm(
                              context,
                              'Estornar movimento?',
                              'Será criado um movimento compensatório. O registro original será preservado.',
                            )) {
                              try {
                                await store.mutate(
                                  '/v1/movements/${entry['id']}/reversal',
                                  {'confirmed': true},
                                );
                                if (mounted) setState(() {});
                              } catch (e) {
                                showMessage(humanError(e));
                              }
                            }
                          },
                          child: const Text('Estornar com registro'),
                        ),
                    ],
                  ),
                ),
              if (v['next_cursor'] != null)
                const Notice(
                  'Exibindo os primeiros 50 registros. A exportação em Privacidade inclui todo o histórico autorizado.',
                ),
            ],
          );
        },
      ),
    ],
  );
  Widget alerts() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Alertas',
        'Estoque, validade e informações que merecem sua conferência.',
      ),
      if (store.alerts.isEmpty)
        const EmptyView(
          title: 'Tudo conferido por aqui',
          description:
              'Nenhum alerta de estoque ou validade na última consulta.',
          asset: 'completed',
        ),
      for (final alert in store.alerts)
        link(
          alert['kind'] == 'low_stock'
              ? 'Reposição para conferir'
              : alert['kind'] == 'expired'
              ? 'Lote vencido'
              : 'Validade próxima',
          identity(Map<String, dynamic>.from(alert['medication'])),
          Icons.warning_amber_rounded,
          '/inventory/lots',
          {'medication': alert['medication']},
        ),
    ],
  );
  Widget shopping() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Lista de compras',
        'Planeje a reposição. O estoque só aumenta quando você confirma o recebimento.',
      ),
      if (store.scope('manage_shopping'))
        action('Adicionar item', Icons.add, '/shopping-list/new'),
      const SizedBox(height: 20),
      if (store.shopping.isEmpty)
        const EmptyView(
          title: 'Sua lista está vazia',
          description: 'Adicione os medicamentos que pretende repor.',
          asset: 'stock-box',
        ),
      for (final item in store.shopping)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                identity(Map<String, dynamic>.from(item['medication'])),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${number(item['quantity'])} ${unitLabels[item['unit']]} · ${item['status'] == 'pendente'
                    ? 'Aguardando recebimento'
                    : item['status'] == 'recebimento_confirmado'
                    ? 'Recebimento confirmado'
                    : 'Cancelado'}',
              ),
              if (item['status'] == 'pendente') ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: () => go(context, '/prices/search', {
                        'medication': item['medication'],
                      }),
                      child: const Text('Buscar ofertas'),
                    ),
                    if (store.scope('manage_stock'))
                      FilledButton(
                        onPressed: () => go(context, '/shopping-list/receive', {
                          'item': item,
                        }),
                        child: const Text('Confirmar recebimento'),
                      ),
                    TextButton(
                      onPressed: () async {
                        if (await confirm(
                          context,
                          'Remover da lista?',
                          'O item será cancelado, sem alterar o estoque.',
                        )) {
                          try {
                            await store.mutate(
                              '/v1/shopping-items/${item['id']}',
                              {},
                              method: 'DELETE',
                            );
                          } catch (e) {
                            showMessage(humanError(e));
                          }
                        }
                      },
                      child: const Text('Remover'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
    ],
  );
  Widget prices() {
    if (store.medications.isEmpty)
      return EmptyView(
        title: 'Qual apresentação vamos buscar?',
        description:
            'Cadastre um medicamento para identificar concentração, forma e quantidade com precisão.',
        asset: 'no-offers',
        action: action('Adicionar medicamento', Icons.add, '/medications/new'),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(
          'Buscar preços',
          'A mesma apresentação, com origem, horário e condições verificáveis.',
        ),
        const Notice(
          'Nenhuma farmácia parceira está conectada neste ambiente. Não exibimos preços sem fonte autorizada.',
        ),
        Editor(
          fields: [
            FieldSpec(
              'medication_id',
              'Apresentação',
              initial: args['medication']?['id'] ?? '',
              options: {
                for (final med in store.medications) med['id']: identity(med),
              },
            ),
            const FieldSpec(
              'postal_code',
              'CEP',
              helper:
                  '8 dígitos, sem traço. A localização é opcional e informada por você.',
              numeric: true,
            ),
            const FieldSpec(
              'fulfillment',
              'Forma de recebimento',
              initial: 'retirada',
              options: {'retirada': 'Retirada', 'entrega': 'Entrega'},
            ),
          ],
          label: 'Consultar fontes',
          submit: (v) async {
            final result = await store.api(
              '/v1/offers?presentation_id=${v['medication_id']}&postal_code=${v['postal_code']}&fulfillment=${v['fulfillment']}',
            );
            if (!mounted) return;
            go(context, '/prices/results', result);
          },
        ),
      ],
    );
  }

  Widget noOffers() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading(
        'Ofertas verificadas',
        'Preço e disponibilidade dependem da farmácia e do momento da consulta.',
      ),
      EmptyView(
        title: 'Nenhuma oferta verificada no momento',
        description:
            'As fontes comerciais autorizadas ainda não foram conectadas. Você pode continuar organizando sua lista e seu estoque.',
        asset: 'no-offers',
        action: action(
          'Ver lista de compras',
          Icons.shopping_bag_outlined,
          '/shopping-list',
        ),
      ),
    ],
  );
}

class ApiView extends StatefulWidget {
  const ApiView({
    super.key,
    required this.store,
    required this.path,
    required this.builder,
  });
  final AppStore store;
  final String path;
  final Widget Function(Json) builder;
  @override
  State<ApiView> createState() => _ApiViewState();
}

class _ApiViewState extends State<ApiView> {
  late Future<Json> future;
  @override
  void initState() {
    super.initState();
    future = widget.store.fetch(widget.path);
  }

  @override
  void didUpdateWidget(covariant ApiView old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || !widget.store.syncing)
      future = widget.store.fetch(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
      if (snapshot.hasError)
        return Column(
          children: [
            Notice(humanError(snapshot.error!), warning: true),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => future = widget.store.fetch(widget.path)),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        );
      return widget.builder(snapshot.data!);
    },
  );
}
