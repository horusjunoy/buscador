import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'vault.dart';
import 'reminders.dart';

typedef Json = Map<String, dynamic>;
String newId() {
  final random = Random.secure();
  final b = List.generate(16, (_) => random.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
List<Json> rows(dynamic value) => (value as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

class ApiError implements Exception {
  final int status;
  final String message;
  ApiError(this.status, this.message);
  @override
  String toString() => message;
}

String humanError(Object error) {
  if (error is ApiError) return error.message;
  if (error is FormatException)
    return 'Confira os números e as datas no formato solicitado.';
  if (error is TimeoutException || error is http.ClientException)
    return 'Não foi possível conectar ao serviço. Confira a rede e tente novamente.';
  return 'Não foi possível concluir esta ação. Confira os dados e tente novamente.';
}

class AppStore extends ChangeNotifier {
  AppStore({http.Client? client, Vault? vault})
    : client = client ?? http.Client(),
      vault = vault ?? Vault();
  final http.Client client;
  final Vault vault;
  Future<void> persistenceTail = Future.value();
  final reminders = Reminders();
  Timer? expiryTimer;
  bool get expired =>
      expiresAt != null && !DateTime.parse(expiresAt!).isAfter(DateTime.now());
  void expireLocalSession() {
    token = null;
    cache = {};
    error =
        'Sua sessão terminou. Entre na mesma conta para conferir os registros pendentes.';
    notifyListeners();
    persist();
  }

  void armExpiry() {
    expiryTimer?.cancel();
    if (expiresAt == null || token == null) return;
    final remaining = DateTime.parse(expiresAt!).difference(DateTime.now());
    if (remaining <= Duration.zero) {
      expireLocalSession();
      return;
    }
    expiryTimer = Timer(remaining, expireLocalSession);
  }

  String? requestedDoseId;
  String? token,
      accountId,
      expiresAt,
      selectedId,
      lastSync,
      error,
      persistenceWarning;
  bool loading = true, offline = false, syncing = false, initialized = false;
  Json cache = {};
  List<Json> outbox = [];
  Map<String, String> mutationKeys = {};
  static const configuredBase = String.fromEnvironment('API_URL');
  String get base => configuredBase.isNotEmpty
      ? configuredBase
      : (kIsWeb
            ? Uri.base.origin
            : defaultTargetPlatform == TargetPlatform.iOS
            ? 'http://127.0.0.1:8765'
            : 'http://10.0.2.2:8765');
  List<Json> get persons => rows(cache['persons']);
  Json? get person => persons.where((p) => p['id'] == selectedId).firstOrNull;
  List<Json> get medications => rows(cache['medications']);
  List<Json> get doses => rows(cache['doses']);
  List<Json> get plans => rows(cache['plans']);
  List<Json> get inventory => rows(cache['inventory']);
  List<Json> get shopping => rows(cache['shopping']);
  List<Json> get alerts => rows(cache['alerts']);
  bool get signedIn => token != null;
  bool scope(String value) =>
      (person?['scopes'] as List? ?? []).contains(value);

  Future<Json> api(
    String path, {
    String method = 'GET',
    Json? body,
    String? key,
  }) async {
    final requestToken = token;
    final request = http.Request(method, Uri.parse('$base$path'));
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (key != null) request.headers['Idempotency-Key'] = key;
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 12)),
    );
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (requestToken != null && requestToken != token)
      throw ApiError(
        401,
        'A sessão mudou. Este resultado foi descartado por segurança.',
      );
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && !path.startsWith('/v1/auth/')) {
        token = null;
        cache = {};
        error =
            'Sua sessão terminou. Entre na mesma conta para conferir os registros pendentes.';
        notifyListeners();
      }
      throw ApiError(
        response.statusCode,
        result['detail'] as String? ??
            'Não foi possível concluir. Tente novamente.',
      );
    }
    offline = false;
    return result;
  }

  Future<void> persist() {
    final next = persistenceTail.then((_) => writeSnapshot());
    persistenceTail = next;
    return next;
  }

  Future<void> writeSnapshot() async {
    if (persistenceWarning != null) return;
    try {
      await vault.write(
        jsonEncode({
          'token': token,
          'account_id': accountId,
          'expires_at': expiresAt,
          'selected_id': selectedId,
          'last_sync': lastSync,
          'cache': cache,
          'outbox': outbox,
          'mutation_keys': mutationKeys,
        }),
      );
    } catch (_) {
      persistenceWarning =
          'O armazenamento protegido está indisponível. Registros offline estão desativados neste dispositivo.';
    }
  }

  Future<void> initialize() async {
    reminders.listen((id) {
      requestedDoseId = id;
      notifyListeners();
    });
    try {
      final stored = await vault.read();
      if (stored != null) {
        final value = jsonDecode(stored) as Json;
        token = value['token'];
        accountId = value['account_id'];
        expiresAt = value['expires_at'];
        selectedId = value['selected_id'];
        lastSync = value['last_sync'];
        cache = Map<String, dynamic>.from(value['cache'] ?? {});
        outbox = rows(value['outbox']);
        mutationKeys = Map<String, String>.from(value['mutation_keys'] ?? {});
        if (expiresAt == null ||
            !DateTime.parse(expiresAt!).isAfter(DateTime.now())) {
          token = null;
          cache = {};
          await persist();
        }
      }
    } catch (_) {
      persistenceWarning =
          'Armazenamento protegido indisponível. Use o modo conectado.';
    }
    initialized = true;
    armExpiry();
    if (token != null) await refresh();
    try {
      requestedDoseId = await reminders.initialDose();
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  Future<void> authenticate(
    String email,
    String password, {
    bool register = false,
  }) async {
    final result = await api(
      register ? '/v1/auth/register' : '/v1/auth/session',
      method: 'POST',
      body: {
        'email': email,
        'password': password,
        if (register) 'privacy_acknowledged': true,
      },
    );
    if (accountId != null &&
        accountId != result['account_id'] &&
        (outbox.isNotEmpty || mutationKeys.isNotEmpty)) {
      await client.post(
        Uri.parse('$base/v1/auth/logout'),
        headers: {'Authorization': 'Bearer ${result['access_token']}'},
      );
      throw ApiError(
        409,
        'Há registros pendentes de outra conta. Entre na conta anterior e confira a sincronização antes de trocar.',
      );
    }
    if (accountId != result['account_id']) {
      cache = {};
      selectedId = null;
      outbox = [];
      mutationKeys = {};
    }
    token = result['access_token'];
    accountId = result['account_id'];
    expiresAt = result['expires_at'];
    armExpiry();
    error = null;
    await persist();
    await refresh();
  }

  Future<void> refresh() async {
    if (expired) {
      expireLocalSession();
      return;
    }
    if (token == null || syncing) return;
    syncing = true;
    error = null;
    notifyListeners();
    try {
      await api('/v1/auth/me');
      await flush();
      final people = rows((await api('/v1/persons'))['items']);
      cache['persons'] = people;
      if (!people.any((p) => p['id'] == selectedId))
        selectedId = people.firstOrNull?['id'];
      if (selectedId != null) {
        final prefix = '/v1/persons/$selectedId';
        final today =
            person?['local_today'] as String? ?? isoDay(DateTime.now());
        final results = await Future.wait([
          scope('view_medications')
              ? api('$prefix/medications')
              : Future.value({'items': []}),
          scope('view_medications')
              ? api('$prefix/dose-occurrences?start=$today&end=$today')
              : Future.value({'items': []}),
          scope('view_medications')
              ? api('$prefix/plans')
              : Future.value({'items': []}),
          scope('view_medications')
              ? api('$prefix/replenishment')
              : Future.value({'items': []}),
          scope('manage_shopping')
              ? api('$prefix/shopping-items')
              : Future.value({'items': []}),
          scope('view_medications')
              ? api('$prefix/alerts')
              : Future.value({'items': []}),
        ]);
        for (var i = 0; i < results.length; i++) {
          cache[[
                'medications',
                'doses',
                'plans',
                'inventory',
                'shopping',
                'alerts',
              ][i]] =
              results[i]['items'];
        }
        if (scope('view_medications')) {
          final until = isoDay(
            DateTime.parse(today).add(const Duration(days: 7)),
          );
          final upcoming = await api(
            '$prefix/dose-occurrences?start=$today&end=$until',
          );
          cache['upcoming'] = upcoming['items'];
        }
        try {
          await reminders.schedule(rows(cache['upcoming']));
        } catch (_) {}
      } else {
        cache.removeWhere((key, _) => key != 'persons');
      }
      offline = false;
      lastSync = DateTime.now().toUtc().toIso8601String();
      await persist();
    } on ApiError catch (e) {
      if (e.status == 403 || e.status == 404) {
        cache = {};
        selectedId = null;
      }
      error = e.message;
    } catch (_) {
      offline = true;
      error =
          'Sem conexão com o serviço. Os dados exibidos são da última sincronização.';
    } finally {
      syncing = false;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectPerson(String id) async {
    if (syncing || selectedId == id) return;
    selectedId = id;
    cache.removeWhere((k, _) => k != 'persons');
    notifyListeners();
    await refresh();
  }

  Future<Json> mutate(
    String path,
    Json body, {
    String method = 'POST',
    String? key,
  }) async {
    final fingerprint = sha256
        .convert(utf8.encode('$method:$path:${jsonEncode(body)}'))
        .toString();
    if (mutationKeys.isNotEmpty && !mutationKeys.containsKey(fingerprint))
      throw ApiError(
        409,
        'Há uma alteração cuja resposta ainda não foi confirmada. Confira em Mais → Sincronização antes de iniciar outra alteração.',
      );
    if (persistenceWarning != null)
      throw ApiError(
        503,
        'O armazenamento protegido está indisponível. Esta alteração exige uma chave persistente para evitar duplicidade.',
      );
    final commandKey = mutationKeys.putIfAbsent(
      fingerprint,
      () => key ?? newId(),
    );
    await persist();
    if (persistenceWarning != null) {
      mutationKeys.remove(fingerprint);
      throw ApiError(
        503,
        'Não foi possível salvar a chave de segurança da alteração. Nenhum comando foi enviado.',
      );
    }
    Json result;
    try {
      result = await api(path, method: method, body: body, key: commandKey);
    } on ApiError catch (error) {
      if (error.status < 500 && error.status != 408) {
        mutationKeys.remove(fingerprint);
        await persist();
      }
      rethrow;
    }
    mutationKeys.remove(fingerprint);
    await persist();
    await refresh();
    return result;
  }

  Future<Json> fetch(String path) async {
    final selectedAtStart = selectedId;
    if (expired) {
      expireLocalSession();
      throw ApiError(401, 'Sua sessão terminou. Entre novamente.');
    }
    final details = Map<String, dynamic>.from(cache['details'] ?? {});
    if (offline) {
      if (details[path] != null)
        return Map<String, dynamic>.from(details[path]);
      throw ApiError(
        503,
        'Esta informação ainda não está disponível offline. Conecte-se e tente novamente.',
      );
    }
    final result = await api(path);
    if (selectedAtStart != selectedId)
      throw ApiError(
        409,
        'O perfil selecionado mudou. Abra novamente a informação.',
      );
    details[path] = result;
    cache['details'] = details;
    await persist();
    return result;
  }

  bool pending(String id) => outbox.any((q) => q['occurrence_id'] == id);
  Future<String> recordDose(Json occurrence, Json payload) async {
    if (expired) {
      expireLocalSession();
      throw ApiError(
        401,
        'Sua sessão terminou. Entre novamente antes de registrar.',
      );
    }
    if (pending(occurrence['id']))
      throw ApiError(
        409,
        'Esta dose já possui um registro local. Confira a sincronização.',
      );
    final command = {
      'occurrence_id': occurrence['id'],
      'idempotency_key': newId(),
      'payload': payload,
      'queue_state': 'pending',
    };
    if (persistenceWarning != null) {
      await api(
        '/v1/dose-occurrences/${occurrence['id']}/actions',
        method: 'POST',
        body: payload,
        key: command['idempotency_key'] as String,
      );
      await refresh();
      return 'Registro confirmado pelo serviço.';
    }
    outbox.add(command);
    await persist();
    if (persistenceWarning != null) {
      outbox.remove(command);
      throw ApiError(
        503,
        'Não foi possível salvar o registro no armazenamento protegido. Conecte-se para registrar diretamente no serviço.',
      );
    }
    notifyListeners();
    await refresh();
    return pending(occurrence['id'])
        ? 'Registro salvo neste dispositivo; confira o estado da sincronização.'
        : 'Registro confirmado pelo serviço.';
  }

  Future<void> flush() async {
    final commands = outbox
        .where((q) => q['queue_state'] == 'pending')
        .take(50)
        .toList();
    if (commands.isEmpty) return;
    final response = await api(
      '/v1/sync/commands',
      method: 'POST',
      body: {
        'commands': commands
            .map(
              (q) => {
                'occurrence_id': q['occurrence_id'],
                'idempotency_key': q['idempotency_key'],
                'payload': q['payload'],
              },
            )
            .toList(),
      },
    );
    for (final result in rows(response['items'])) {
      final item = outbox
          .where((q) => q['idempotency_key'] == result['idempotency_key'])
          .firstOrNull;
      if (item == null) continue;
      if (result['status'] == 'confirmed') {
        outbox.remove(item);
      } else {
        item['queue_state'] = 'conflict';
        item['detail'] = result['detail'];
      }
    }
    await persist();
  }

  Future<void> resolveCommand(String key) async {
    outbox.removeWhere((q) => q['idempotency_key'] == key);
    await persist();
    notifyListeners();
  }

  Future<void> acknowledgeUnknownMutations() async {
    await refresh();
    if (offline || error != null)
      throw ApiError(
        503,
        'Reconecte e confira os registros no serviço antes de encerrar a pendência.',
      );
    mutationKeys.clear();
    await persist();
    notifyListeners();
  }

  Future<void> logout() async {
    if (token != null) await api('/v1/auth/logout', method: 'POST');
    expiryTimer?.cancel();
    token = null;
    accountId = null;
    expiresAt = null;
    selectedId = null;
    cache = {};
    outbox = [];
    mutationKeys = {};
    offline = false;
    error = null;
    await persistenceTail;
    try {
      await reminders.clear();
    } finally {
      await vault.clear();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    expiryTimer?.cancel();
    client.close();
    super.dispose();
  }
}
