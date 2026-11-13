import 'package:flutter/material.dart';
import '../core/design.dart';
import '../core/store.dart';
import 'editor.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.store, this.initial = '/'});
  final AppStore store;
  final String initial;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late String mode;
  @override
  void initState() {
    super.initState();
    mode = widget.initial.contains('signup')
        ? 'signup'
        : widget.initial.contains('recover')
        ? 'recover'
        : widget.initial == '/' && widget.store.accountId == null
        ? 'welcome'
        : 'login';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/branding/brand-mark-512.png',
                      width: 46,
                      height: 46,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 12),
                    const Flexible(
                      child: Text(
                        'Buscador de\nMedicamentos',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: Design.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (mode == 'welcome') ...[
                  Image.asset(
                    'assets/illustrations/daily-reminder-preview.png',
                    height: 180,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Mais cuidado.\nMais tranquilidade.',
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Organize seus medicamentos, acompanhe o estoque e registre sua rotina em um só lugar.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Notice(
                    'Você registra a orientação que já recebeu. O aplicativo não prescreve nem altera tratamentos.',
                    icon: Icons.shield_outlined,
                  ),
                  FilledButton(
                    onPressed: () => setState(() => mode = 'signup'),
                    child: const Text('Começar meu cuidado'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => mode = 'login'),
                    child: const Text('Já tenho uma conta'),
                  ),
                ] else ...[
                  Text(
                    mode == 'signup'
                        ? 'Seu cuidado começa aqui'
                        : mode == 'recover'
                        ? 'Recuperar acesso'
                        : 'Que bom ter você aqui',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mode == 'signup'
                        ? 'Crie sua conta e adicione seu primeiro perfil.'
                        : mode == 'recover'
                        ? 'O envio depende de um canal de recuperação configurado.'
                        : 'Entre para acompanhar sua rotina.',
                  ),
                  const SizedBox(height: 24),
                  if (widget.store.error != null)
                    Notice(widget.store.error!, warning: true),
                  Editor(
                    key: ValueKey(mode),
                    fields: [
                      const FieldSpec('email', 'E-mail'),
                      if (mode != 'recover')
                        const FieldSpec(
                          'password',
                          'Senha',
                          obscure: true,
                          helper: 'De 12 a 128 caracteres.',
                        ),
                    ],
                    confirmation: mode == 'signup'
                        ? 'Entendi que esta versão local armazena dados de saúde e li as informações de privacidade.'
                        : null,
                    label: mode == 'signup'
                        ? 'Criar conta'
                        : mode == 'recover'
                        ? 'Solicitar instruções'
                        : 'Entrar',
                    submit: (values) async {
                      if (mode == 'recover') {
                        final result = await widget.store.api(
                          '/v1/auth/recover',
                          method: 'POST',
                          body: {'email': values['email']},
                        );
                        if (!context.mounted) return;
                        await showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Solicitação recebida'),
                            content: Text(
                              '${result['message']}\n\nO envio de e-mail ainda não está configurado neste ambiente.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('Entendi'),
                              ),
                            ],
                          ),
                        );
                      } else {
                        await widget.store.authenticate(
                          values['email']!,
                          values['password']!,
                          register: mode == 'signup',
                        );
                      }
                    },
                  ),
                  if (mode == 'login')
                    TextButton(
                      onPressed: () => setState(() => mode = 'recover'),
                      child: const Text('Esqueci minha senha'),
                    ),
                  TextButton(
                    onPressed: () => setState(
                      () => mode = mode == 'signup' ? 'login' : 'signup',
                    ),
                    child: Text(
                      mode == 'signup'
                          ? 'Já tenho uma conta · Entrar'
                          : 'Ainda não tenho conta · Cadastrar',
                    ),
                  ),
                  TextButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Privacidade desta versão'),
                        content: const SingleChildScrollView(
                          child: Text(
                            'Use apenas dados sintéticos neste ambiente de desenvolvimento. Dados de saúde ficam associados à sua conta e aos perfis que você criar. O acesso de cuidadores exige concessão explícita por perfil e ação. Não há publicidade nem transmissão de tratamentos para farmácias. O armazenamento local usa proteção da plataforma. Exportação e solicitação de exclusão ficam em Mais → Privacidade. Política jurídica, retenção e tratamento de menores aguardam revisão antes de qualquer piloto externo.',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Fechar'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('Ler informações de privacidade'),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Versão local de desenvolvimento · use dados sintéticos',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Design.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
