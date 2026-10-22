import 'package:floating_snackbar/floating_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/ui.dart';
import 'avatar_picker.dart';
import 'password_strength.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  int _avatarIndex = 1;
  bool _creatingAccount = false;
  bool _showWelcome = true;
  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final creatingAccount = _creatingAccount;
    setState(() {
      _busy = true;
    });
    try {
      if (_creatingAccount) {
        final authenticated = await ref.read(authViewModelProvider).signUp(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
          avatarIndex: _avatarIndex,
        );
        if (authenticated) {
          await ref.read(authViewModelProvider).signOut();
        }
        if (mounted) {
          setState(() {
            _creatingAccount = false;
          });
          showFloatingNotice(
            context,
            authenticated
                ? 'Conta criada. Entre com seu e-mail e senha.'
                : 'Conta criada. Confirme o e-mail e depois entre no app.',
            type: FloatingSnackBarType.success,
          );
        }
      } else {
        await ref.read(authViewModelProvider).signIn(
          _email.text,
          _password.text,
        );
      }
    } catch (error) {
      if (mounted) {
        showFloatingNotice(
          context,
          _friendlyError(error, creatingAccount: creatingAccount),
          type: FloatingSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordRecovery() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _PasswordRecoveryRequestDialog(
        initialEmail: _email.text.trim(),
      ),
    );
    if (email == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(authViewModelProvider).sendPasswordRecovery(email);
      if (mounted) {
        showFloatingNotice(
          context,
          'Se o e-mail estiver cadastrado, você receberá um link para redefinir a senha.',
          type: FloatingSnackBarType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        final message = _isConnectivityError(error)
            ? 'Sem conexão. Verifique sua internet e tente novamente.'
            : 'Não foi possível enviar o e-mail de recuperação. Tente novamente.';
        showFloatingNotice(
          context,
          message,
          type: FloatingSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isConnectivityError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('timed out') ||
        text.contains('network is unreachable') ||
        text.contains('connection refused');
  }

  String _friendlyError(Object error, {required bool creatingAccount}) {
    final text = error is AuthException ? error.message : error.toString();
    final normalized = text.toLowerCase();
    if (_isConnectivityError(error)) {
      return 'Sem conexão. Verifique sua internet e tente novamente.';
    }
    if (normalized.contains('invalid login credentials') ||
        normalized.contains('invalid credentials') ||
        normalized.contains('invalid_grant')) {
      return 'E-mail ou senha incorretos.';
    }
    if (normalized.contains('already registered')) {
      return 'Este e-mail já tem uma conta. Entre com sua senha.';
    }
    if ((creatingAccount || _creatingAccount) &&
        (normalized.contains('password') || normalized.contains('weak_password'))) {
      return 'A senha precisa ter pelo menos 8 caracteres e atingir o nível médio.';
    }
    if (!creatingAccount && error is AuthException) {
      return 'E-mail ou senha incorretos.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    if (_showWelcome) return _buildWelcome(context);
    return _buildAuth(context);
  }

  Widget _buildWelcome(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: constraints.maxHeight < 700 ? 300 : 360,
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 34),
                        child: Image.asset(
                          'assets/image/finance_wallet_hero.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'MedPlanner',
                      style: TextStyle(
                        color: AppTheme.lime,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mais clareza para cuidar do seu dinheiro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted, fontSize: 14),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: () => setState(() {
                          _creatingAccount = true;
                          _showWelcome = false;
                        }),
                        child: const Text(
                          'Começar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _creatingAccount = false;
                        _showWelcome = false;
                      }),
                      child: const Text('Já tenho uma conta · Entrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuth(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Voltar',
                        onPressed: _busy
                            ? null
                            : () => setState(() => _showWelcome = true),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    if (!_creatingAccount) ...[
                      SizedBox(
                        height: constraints.maxHeight < 700 ? 155 : 200,
                        child: Image.asset(
                          'assets/image/finance_wallet_hero.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Text(
                        'Criar conta',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crie seu acesso para organizar suas finanças.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 22),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _creatingAccount ? 'Seus dados' : 'Bem-vindo de volta',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _creatingAccount
                                  ? 'Preencha os campos para continuar.'
                                  : 'Entre para continuar no seu planejamento.',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                            const SizedBox(height: 20),
                            if (_creatingAccount) ...[
                              TextFormField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Nome',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (value) => value == null ||
                                        value.trim().isEmpty
                                    ? 'Informe seu nome.'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        final selected = await showAvatarPicker(
                                          context,
                                          _avatarIndex,
                                        );
                                        if (selected != null && mounted) {
                                          setState(() => _avatarIndex = selected);
                                        }
                                      },
                                icon: AvatarPhoto(index: _avatarIndex, radius: 18),
                                label: const Text('Escolher avatar'),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'E-mail',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) => value == null ||
                                      !value.trim().contains('@')
                                  ? 'Informe um e-mail válido.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: _hidePassword,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _hidePassword
                                      ? 'Mostrar senha'
                                      : 'Ocultar senha',
                                  onPressed: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Informe sua senha.';
                                }
                                if (_creatingAccount &&
                                    !PasswordPolicy.isAcceptable(value)) {
                                  return 'Use 8 caracteres ou mais e combine tipos diferentes de caracteres.';
                                }
                                return null;
                              },
                              onChanged: (_) {
                                if (_creatingAccount) setState(() {});
                              },
                              onFieldSubmitted: (_) {
                                if (!_busy && !_creatingAccount) _submit();
                              },
                            ),
                            if (_creatingAccount)
                              PasswordStrengthIndicator(password: _password.text),
                            if (!_creatingAccount)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _busy ? null : _sendPasswordRecovery,
                                  child: const Text('Esqueci minha senha'),
                                ),
                              ),
                            if (_creatingAccount) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPassword,
                                obscureText: _hideConfirmation,
                                decoration: InputDecoration(
                                  labelText: 'Confirmar senha',
                                  prefixIcon: const Icon(Icons.lock_reset),
                                  suffixIcon: IconButton(
                                    tooltip: _hideConfirmation
                                        ? 'Mostrar senha'
                                        : 'Ocultar senha',
                                    onPressed: () => setState(
                                      () => _hideConfirmation =
                                          !_hideConfirmation,
                                    ),
                                    icon: Icon(
                                      _hideConfirmation
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) => value != _password.text
                                    ? 'As senhas não conferem.'
                                    : null,
                                onFieldSubmitted: (_) {
                                  if (!_busy) _submit();
                                },
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _creatingAccount ? 'Cadastrar' : 'Entrar',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _creatingAccount
                                        ? 'Já tem uma conta?'
                                        : 'Ainda não tem uma conta?',
                                    style: TextStyle(color: AppTheme.muted),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                          _creatingAccount = !_creatingAccount;
                                        }),
                                  child: Text(
                                    _creatingAccount ? 'Entrar' : 'Criar conta',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Seus dados financeiros permanecem no seu aparelho.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _PasswordRecoveryRequestDialog extends StatefulWidget {
  const _PasswordRecoveryRequestDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_PasswordRecoveryRequestDialog> createState() =>
      _PasswordRecoveryRequestDialogState();
}

class _PasswordRecoveryRequestDialogState
    extends State<_PasswordRecoveryRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppTheme.surface,
    scrollable: true,
    title: const Text('Recuperar senha'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'E-mail da sua conta',
          prefixIcon: Icon(Icons.email_outlined),
        ),
        validator: (value) => value == null || !value.trim().contains('@')
            ? 'Informe um e-mail válido.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _emailController.text.trim());
          }
        },
        child: const Text('Enviar link'),
      ),
    ],
  );
}
