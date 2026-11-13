import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:buscador/app.dart';
import 'package:buscador/core/design.dart';
import 'package:buscador/core/store.dart';
import 'package:buscador/core/vault.dart';
import 'package:buscador/features/editor.dart';
import 'package:buscador/features/screens.dart';

class MemoryVault extends Vault {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async {
    data = value;
  }

  @override
  Future<void> clear() async {
    data = null;
  }
}

class DelayedVault extends MemoryVault {
  final firstStarted = Completer<void>();
  final release = Completer<void>();
  int writes = 0;
  @override
  Future<void> write(String value) async {
    writes++;
    if (writes == 1) {
      firstStarted.complete();
      await release.future;
    }
    data = value;
  }
}

void main() {
  test('all 35 canonical screens have distinct destinations', () {
    expect(screens.length, 35);
    expect(screens.values.toSet().length, 35);
  });
  testWidgets('new account starts without invented patient or prices', (
    tester,
  ) async {
    final store = AppStore(vault: MemoryVault())
      ..loading = false
      ..initialized = true;
    await tester.pumpWidget(BuscadorApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Mais cuidado.\nMais tranquilidade.'), findsOneWidget);
    expect(find.textContaining('Losartana'), findsNothing);
    expect(find.textContaining('R\$'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets('critical form requires explicit acknowledgment', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Editor(
            fields: const [FieldSpec('quantity', 'Quantidade')],
            confirmation: 'Conferi os dados',
            submit: (v) async {
              saved = true;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '1');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(saved, false);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(saved, true);
  });
  testWidgets('empty dashboard supports large text at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore(vault: MemoryVault())
      ..token = 'synthetic-only'
      ..initialized = true
      ..loading = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: BuscadorApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('De quem vamos cuidar?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  test(
    'offline command survives restart and syncs with the same key',
    () async {
      final vault = MemoryVault();
      final offline =
          AppStore(
              client: MockClient(
                (_) async => throw http.ClientException('offline'),
              ),
              vault: vault,
            )
            ..token = 'synthetic-only'
            ..accountId = 'synthetic-account'
            ..expiresAt = DateTime.now()
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String();
      final payload = {
        'action': 'tomada_confirmada',
        'version': 1,
        'client_event_id': newId(),
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'confirmed': true,
      };
      await offline.recordDose({'id': 'synthetic-occurrence'}, payload);
      expect(offline.outbox.length, 1);
      final key = offline.outbox.single['idempotency_key'];
      expect(jsonDecode(vault.data!)['outbox'][0]['idempotency_key'], key);
      final sent = <String>[];
      final online = AppStore(
        client: MockClient((request) async {
          if (request.url.path == '/v1/sync/commands') {
            final body = jsonDecode(request.body);
            sent.add(body['commands'][0]['idempotency_key']);
            return http.Response(
              jsonEncode({
                'items': [
                  {'idempotency_key': key, 'status': 'confirmed', 'result': {}},
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(request.url.path == '/v1/persons' ? {'items': []} : {}),
            200,
          );
        }),
        vault: vault,
      );
      await online.initialize();
      expect(sent, [key]);
      expect(online.outbox, isEmpty);
      await online.refresh();
      expect(sent, [key]);
      offline.dispose();
      online.dispose();
    },
  );
  test(
    'a rejected offline command remains visible for reconciliation',
    () async {
      final store = AppStore(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'items': [
                {
                  'idempotency_key': 'command-key',
                  'status': 'rejected',
                  'detail': 'Acesso revogado',
                  'http_status': 404,
                },
              ],
            }),
            200,
          ),
        ),
        vault: MemoryVault(),
      )..token = 'synthetic-only';
      store.outbox = [
        {
          'occurrence_id': 'id',
          'idempotency_key': 'command-key',
          'payload': {},
          'queue_state': 'pending',
        },
      ];
      await store.flush();
      expect(store.outbox.single['queue_state'], 'conflict');
      expect(store.outbox.single['detail'], 'Acesso revogado');
      store.dispose();
    },
  );
  test(
    'a lost mutation response keeps its durable idempotency key across restart',
    () async {
      final vault = MemoryVault();
      final keys = <String>[];
      var fail = true;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/test-mutation') {
          keys.add(request.headers['idempotency-key']!);
          if (fail) {
            fail = false;
            throw http.ClientException('response lost');
          }
          return http.Response('{"accepted":true}', 200);
        }
        return http.Response(
          request.url.path == '/v1/persons' ? '{"items":[]}' : '{}',
          200,
        );
      });
      final first = AppStore(client: client, vault: vault)
        ..token = 'synthetic-only'
        ..accountId = 'synthetic-account'
        ..expiresAt = DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String();
      await expectLater(
        first.mutate('/v1/test-mutation', {'quantity': '30'}),
        throwsA(isA<http.ClientException>()),
      );
      expect(first.mutationKeys.length, 1);
      await expectLater(
        first.mutate('/v1/test-mutation', {'quantity': '29'}),
        throwsA(isA<ApiError>()),
      );
      expect(keys.length, 1);
      final second = AppStore(client: client, vault: vault);
      await second.initialize();
      await second.mutate('/v1/test-mutation', {'quantity': '30'});
      expect(keys.length, 2);
      expect(keys.first, keys.last);
      expect(second.mutationKeys, isEmpty);
      first.dispose();
      second.dispose();
    },
  );
  test(
    'expired sessions hide and prune health cache while preserving pending command IDs',
    () async {
      final vault = MemoryVault();
      vault.data = jsonEncode({
        'token': 'synthetic-only',
        'account_id': 'synthetic-account',
        'expires_at': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .toUtc()
            .toIso8601String(),
        'cache': {
          'medications': [
            {'name': 'Synthetic confidential field'},
          ],
        },
        'outbox': [
          {'occurrence_id': 'synthetic-id', 'queue_state': 'pending'},
        ],
      });
      final store = AppStore(vault: vault);
      await store.initialize();
      expect(store.signedIn, false);
      expect(store.cache, isEmpty);
      expect(store.outbox.length, 1);
      expect(jsonDecode(vault.data!)['cache'], isEmpty);
      store.dispose();
    },
  );
  testWidgets('desktop navigation paints list tiles on Material', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1250, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore(vault: MemoryVault())
      ..token = 'synthetic-only'
      ..initialized = true
      ..loading = false;
    await tester.pumpWidget(BuscadorApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Início'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets(
    'dose labels have at least AA text contrast on their actual background',
    (tester) async {
      for (final state in [
        'programada',
        'pendente',
        'adiada',
        'tomada_confirmada',
        'nao_tomada_declarada',
        'sem_confirmacao',
        'cancelada',
        'pending_sync',
      ]) {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: StatusLabel(state))),
        );
        await tester.pumpAndSettle();
        final text = tester.widget<Text>(find.text(StatusLabel.labels[state]!));
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(StatusLabel),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration as BoxDecoration;
        final background = Color.alphaBlend(decoration.color!, Colors.white);
        final a = text.style!.color!.computeLuminance(),
            b = background.computeLuminance();
        final ratio = (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: state);
      }
    },
  );
  test(
    'protected snapshots serialize writes instead of restoring stale state',
    () async {
      final vault = DelayedVault();
      final store = AppStore(vault: vault)..cache = {'sequence': 1};
      final first = store.persist();
      await vault.firstStarted.future;
      store.cache = {'sequence': 2};
      final second = store.persist();
      await Future<void>.delayed(Duration.zero);
      expect(vault.writes, 1);
      vault.release.complete();
      await Future.wait([first, second]);
      expect(jsonDecode(vault.data!)['cache']['sequence'], 2);
      store.dispose();
    },
  );
  test(
    'late reads from the previous profile cannot populate the new profile cache',
    () async {
      final response = Completer<http.Response>();
      final store =
          AppStore(
              vault: MemoryVault(),
              client: MockClient((_) => response.future),
            )
            ..token = 'synthetic-only'
            ..selectedId = 'person-A';
      final request = store.fetch('/v1/synthetic-detail');
      store.selectedId = 'person-B';
      response.complete(http.Response('{"name":"Synthetic person A"}', 200));
      await expectLater(request, throwsA(isA<ApiError>()));
      expect(store.cache['details'], isNull);
      store.dispose();
    },
  );
}
