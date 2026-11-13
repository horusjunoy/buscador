import 'package:flutter/material.dart';
import '../core/design.dart';
import '../core/store.dart';

class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.initial = '',
    this.options,
    this.optional = false,
    this.helper,
    this.numeric = false,
    this.obscure = false,
  });
  final String key, label, initial;
  final Map<String, String>? options;
  final bool optional, numeric, obscure;
  final String? helper;
}

class Editor extends StatefulWidget {
  const Editor({
    super.key,
    required this.fields,
    required this.submit,
    this.label = 'Salvar',
    this.confirmation,
    this.intro,
    this.onSuccess,
  });
  final List<FieldSpec> fields;
  final Future<void> Function(Map<String, String>) submit;
  final String label;
  final String? confirmation, intro;
  final VoidCallback? onSuccess;
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final form = GlobalKey<FormState>();
  final Map<String, TextEditingController> controllers = {};
  bool busy = false, confirmed = false;
  String? error;
  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      controllers[f.key] = TextEditingController(text: f.initial);
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (widget.confirmation != null && !confirmed) {
      setState(() => error = 'Confirme as informações antes de continuar.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.submit(
        controllers.map((k, v) => MapEntry(k, v.text.trim())),
      );
      if (!mounted) return;
      widget.onSuccess?.call();
    } catch (e) {
      if (mounted) setState(() => error = humanError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Panel(
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.intro != null) ...[
            Text(widget.intro!),
            const SizedBox(height: 20),
          ],
          for (final f in widget.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: f.options != null
                  ? DropdownButtonFormField<String>(
                      initialValue: controllers[f.key]!.text.isEmpty
                          ? null
                          : controllers[f.key]!.text,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: f.label,
                        helperText: f.helper,
                      ),
                      items: f.options!.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (v) => controllers[f.key]!.text = v ?? '',
                      validator: (v) => !f.optional && (v == null || v.isEmpty)
                          ? 'Selecione uma opção.'
                          : null,
                    )
                  : TextFormField(
                      controller: controllers[f.key],
                      obscureText: f.obscure,
                      enabled: !busy,
                      keyboardType: f.numeric
                          ? const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            )
                          : TextInputType.text,
                      autocorrect: !f.obscure,
                      decoration: InputDecoration(
                        labelText: f.label,
                        helperText: f.helper,
                      ),
                      validator: (v) =>
                          !f.optional && (v == null || v.trim().isEmpty)
                          ? 'Preencha este campo.'
                          : null,
                    ),
            ),
          if (widget.confirmation != null)
            CheckboxListTile(
              value: confirmed,
              onChanged: busy
                  ? null
                  : (v) => setState(() => confirmed = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(widget.confirmation!),
            ),
          if (error != null) Notice(error!, warning: true),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : save,
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.label),
          ),
        ],
      ),
    ),
  );
}
