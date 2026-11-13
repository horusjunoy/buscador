import 'package:flutter/material.dart';
import 'core/design.dart';
import 'core/store.dart';
import 'features/auth.dart';
import 'features/workspace.dart';

class BuscadorApp extends StatefulWidget {
  const BuscadorApp({super.key, required this.store});
  final AppStore store;
  @override
  State<BuscadorApp> createState() => _BuscadorAppState();
}

class _BuscadorAppState extends State<BuscadorApp> {
  final nav = GlobalKey<NavigatorState>();
  bool previous = false;
  @override
  void initState() {
    super.initState();
    previous = widget.store.signedIn;
    widget.store.addListener(sessionChanged);
  }

  void sessionChanged() {
    final occurrenceId = widget.store.requestedDoseId;
    final validId =
        occurrenceId != null &&
        RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(occurrenceId);
    if (occurrenceId != null && !validId) widget.store.requestedDoseId = null;
    if (validId && widget.store.signedIn) {
      widget.store.requestedDoseId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final dose = await widget.store.fetch(
            '/v1/dose-occurrences/$occurrenceId',
          );
          if (dose['person_id'] != widget.store.selectedId)
            await widget.store.selectPerson(dose['person_id']);
          nav.currentState?.pushNamed(
            '/doses/detail',
            arguments: {'dose': dose},
          );
        } catch (_) {
          nav.currentState?.pushNamed('/agenda');
        }
      });
    }
    if (previous != widget.store.signedIn) {
      previous = widget.store.signedIn;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nav.currentState?.popUntil((r) => r.isFirst);
      });
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: nav,
    title: 'Buscador de Medicamentos',
    debugShowCheckedModeBanner: false,
    theme: Design.theme,
    onGenerateRoute: (settings) {
      final route = settings.name ?? '/';
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            if (widget.store.loading && !widget.store.initialized)
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.medication_outlined,
                        size: 64,
                        color: Design.primary,
                      ),
                      SizedBox(height: 24),
                      Text('Buscador de Medicamentos'),
                      SizedBox(height: 24),
                      CircularProgressIndicator(),
                    ],
                  ),
                ),
              );
            if (!widget.store.signedIn)
              return AuthPage(store: widget.store, initial: route);
            return Workspace(
              store: widget.store,
              route: route == '/' ? '/home' : route,
              args: settings.arguments as Json?,
            );
          },
        ),
      );
    },
  );
}
