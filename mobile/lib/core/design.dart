import 'package:flutter/material.dart';

abstract final class Design {
  static const primary = Color(0xFF007A70),
      dark = Color(0xFF005D57),
      ink = Color(0xFF083B3E),
      muted = Color(0xFF52646B);
  static const canvas = Color(0xFFF8FCFB),
      light = Color(0xFFDDF5F0),
      border = Color(0xFFD8E8E6),
      warning = Color(0xFFB9600A);
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: light,
      height: 76,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: border),
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = 20,
  });
  final Widget child;
  final Color color;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Design.border),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

class StatusLabel extends StatelessWidget {
  const StatusLabel(this.status, {super.key});
  final String status;
  static const labels = {
    'programada': 'Programada',
    'pendente': 'Aguardando confirmação',
    'adiada': 'Lembrete adiado',
    'tomada_confirmada': 'Tomada confirmada',
    'nao_tomada_declarada': 'Não tomada · declaração',
    'sem_confirmacao': 'Sem confirmação de uso',
    'cancelada': 'Cancelada',
    'pending_sync': 'Aguardando sincronização',
  };
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'tomada_confirmada' => const Color(0xFF078656),
      'nao_tomada_declarada' => const Color(0xFFB92D37),
      'adiada' => const Color(0xFF17689D),
      'pendente' || 'pending_sync' => Design.warning,
      _ => Design.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        labels[status] ?? status,
        style: TextStyle(
          color: Color.lerp(color, Colors.black, .18),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.description,
    this.asset = 'empty-medicine',
    this.action,
  });
  final String title, description, asset;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Panel(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Image.asset(
              'assets/illustrations/$asset-preview.png',
              height: 128,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(description, textAlign: TextAlign.center),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(
    this.text, {
    super.key,
    this.icon = Icons.info_outline,
    this.warning = false,
  });
  final String text;
  final IconData icon;
  final bool warning;
  @override
  Widget build(BuildContext context) => Panel(
    color: warning ? const Color(0xFFFFF1DD) : Design.light,
    padding: 14,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: warning ? Design.warning : Design.primary, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: warning ? const Color(0xFF824105) : Design.dark,
            ),
          ),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) action!,
      ],
    ),
  );
}
