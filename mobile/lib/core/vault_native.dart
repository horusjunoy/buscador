import 'package:flutter/services.dart';

class Vault {
  static const channel = MethodChannel('br.com.buscador/vault');
  Future<String?> read() => channel.invokeMethod<String>('read');
  Future<void> write(String value) =>
      channel.invokeMethod<void>('write', value);
  Future<void> clear() => channel.invokeMethod<void>('clear');
  Future<void> export(String content) =>
      channel.invokeMethod<void>('export', content);
}
