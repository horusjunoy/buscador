import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Reminders {
  void listen(void Function(String) onOpen) {
    if (kIsWeb) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'openDose' && call.arguments is String)
        onOpen(call.arguments as String);
    });
  }

  Future<String?> initialDose() async {
    if (kIsWeb) return null;
    return channel.invokeMethod<String>('initialDose');
  }

  static const channel = MethodChannel('br.com.buscador/reminders');
  Future<String> permission() async {
    if (kIsWeb)
      return 'Prévia web: lembretes nativos disponíveis no app Android/iOS. Sem garantia de aviso nesta versão web.';
    return await channel.invokeMethod<String>('permission') ??
        'Permissão não informada';
  }

  Future<void> schedule(List<Map<String, dynamic>> doses) async {
    if (kIsWeb) return;
    final future = doses
        .where(
          (d) => ![
            'tomada_confirmada',
            'nao_tomada_declarada',
            'cancelada',
          ].contains(d['status']),
        )
        .map((d) => {'id': d['id'], 'at': d['remind_at'] ?? d['scheduled_at']})
        .where((d) => DateTime.parse(d['at'] as String).isAfter(DateTime.now()))
        .take(60)
        .toList();
    await channel.invokeMethod<void>('schedule', future);
  }

  Future<void> clear() async {
    if (!kIsWeb) await channel.invokeMethod<void>('clear');
  }
}
