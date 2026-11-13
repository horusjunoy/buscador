import 'package:flutter/material.dart';
import '../core/design.dart';
import '../core/store.dart';
import 'pages.dart';

const tabRoutes = ['/home', '/medications', '/agenda', '/inventory', '/more'];
const tabLabels = ['Início', 'Medicamentos', 'Agenda', 'Estoque', 'Mais'];
const tabIcons = [
  Icons.home_outlined,
  Icons.medication_outlined,
  Icons.calendar_month_outlined,
  Icons.inventory_2_outlined,
  Icons.grid_view_rounded,
];

void go(BuildContext context, String route, [Json? args]) =>
    Navigator.of(context).pushNamed(route, arguments: args);
void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
Future<bool> confirm(
  BuildContext context,
  String title,
  String description, {
  String action = 'Confirmar',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class Workspace extends StatelessWidget {
  const Workspace({
    super.key,
    required this.store,
    required this.route,
    this.args,
  });
  final AppStore store;
  final String route;
  final Json? args;
  int get index => route.startsWith('/medications')
      ? 1
      : route.startsWith('/agenda') || route.startsWith('/doses')
      ? 2
      : route.startsWith('/inventory')
      ? 3
      : route == '/home'
      ? 0
      : 4;
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    final editing = RegExp(
      r'/(new|edit|confirm|preview|receive)$',
    ).hasMatch(route);
    void nav(int i) => Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(tabRoutes[i], (r) => r.isFirst);
    final content = Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 12, wide ? 28 : 16, 8),
          child: Row(
            children: [
              if (Navigator.canPop(context))
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Voltar',
                ),
              if (!wide) ...[
                Image.asset(
                  'assets/branding/brand-mark-512.png',
                  width: 36,
                  height: 36,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Buscador de Medicamentos',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ] else
                const Expanded(
                  child: Text(
                    'Seu cuidado, todos os dias',
                    style: TextStyle(color: Design.muted),
                  ),
                ),
              IconButton(
                onPressed: () => go(context, '/alerts'),
                icon: Badge(
                  isLabelVisible: store.alerts.isNotEmpty,
                  child: const Icon(Icons.notifications_none),
                ),
                tooltip: 'Alertas',
              ),
              IconButton(
                onPressed: store.syncing ? null : store.refresh,
                icon: const Icon(Icons.sync),
                tooltip: 'Sincronizar',
              ),
            ],
          ),
        ),
        if (store.syncing) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: store.refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 28 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (store.persons.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  color: Design.primary,
                                ),
                                const Text(
                                  'Cuidando de',
                                  style: TextStyle(color: Design.muted),
                                ),
                                for (final p in store.persons)
                                  ChoiceChip(
                                    label: Text(p['display_name']),
                                    selected: p['id'] == store.selectedId,
                                    onSelected: store.syncing || editing
                                        ? null
                                        : (_) async {
                                            await store.selectPerson(p['id']);
                                            if (context.mounted) nav(0);
                                          },
                                  ),
                                ActionChip(
                                  label: const Text('Adicionar pessoa'),
                                  avatar: const Icon(Icons.add, size: 18),
                                  onPressed: store.syncing || editing
                                      ? null
                                      : () => go(context, '/profiles/new'),
                                ),
                              ],
                            ),
                          ),
                        if (store.error != null)
                          Notice(
                            store.error!,
                            icon: store.offline
                                ? Icons.wifi_off
                                : Icons.info_outline,
                            warning: true,
                          ),
                        if (store.persistenceWarning != null)
                          Notice(store.persistenceWarning!, warning: true),
                        if (store.outbox.isNotEmpty ||
                            store.mutationKeys.isNotEmpty)
                          Notice(
                            '${store.outbox.length + store.mutationKeys.length} registro(s) aguardando sincronização ou conferência. Abra Mais → Sincronização.',
                            icon: Icons.cloud_upload_outlined,
                            warning: true,
                          ),
                        FeaturePage(store: store, route: route, args: args),
                        const SizedBox(height: 28),
                        Text(
                          'Dados protegidos por permissões de perfil.\nÚltima sincronização: ${store.lastSync == null ? 'ainda não realizada' : DateTime.parse(store.lastSync!).toLocal().toString().substring(0, 16)}',
                          style: const TextStyle(
                            color: Design.muted,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 230,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: Design.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/branding/brand-mark-512.png',
                            width: 48,
                            height: 48,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Buscador de\nMedicamentos',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                              color: Design.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < tabRoutes.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            selected: index == i,
                            selectedTileColor: Design.light,
                            selectedColor: Design.dark,
                            leading: Icon(tabIcons[i]),
                            title: Text(tabLabels[i]),
                            onTap: () => nav(i),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Panel(
                        color: Design.light,
                        padding: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              color: Design.primary,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'O cuidado é seu.\nA organização, nossa.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Design.dark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => go(context, '/help'),
                              child: const Text('Precisando de ajuda?'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: content),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: nav,
              destinations: List.generate(
                5,
                (i) => NavigationDestination(
                  icon: Icon(tabIcons[i]),
                  label: tabLabels[i],
                ),
              ),
            ),
    );
  }
}
