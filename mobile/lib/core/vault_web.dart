import 'dart:js_interop';

@JS('buscadorVault.read')
external JSPromise<JSAny?> _read();
@JS('buscadorVault.write')
external JSPromise<JSAny?> _write(JSString value);
@JS('buscadorVault.clear')
external JSPromise<JSAny?> _clear();
@JS('buscadorVault.export')
external JSPromise<JSAny?> _export(JSString value);

class Vault {
  Future<String?> read() async {
    final value = await _read().toDart;
    return value == null ? null : (value as JSString).toDart;
  }

  Future<void> write(String value) async {
    await _write(value.toJS).toDart;
  }

  Future<void> clear() async {
    await _clear().toDart;
  }

  Future<void> export(String content) async {
    await _export(content.toJS).toDart;
  }
}
