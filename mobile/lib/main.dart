import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'app.dart';
import 'core/store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Make real accessible controls available immediately, including the web preview.
  SemanticsBinding.instance.ensureSemantics();
  final store = AppStore();
  runApp(BuscadorApp(store: store));
  store.initialize();
}
