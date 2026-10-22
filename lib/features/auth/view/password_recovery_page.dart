import 'package:floating_snackbar/floating_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/ui.dart';
import 'password_strength.dart';

class PasswordRecoveryPage extends ConsumerStatefulWidget {
  const PasswordRecoveryPage({super.key});

  @override
  ConsumerState<PasswordRecoveryPage> createState() =>
      _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends ConsumerState<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _updated = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authViewModelProvider)
          .updatePassword(_password.text);
      if (mounted) setState(() => _updated = true);
    } catch (error) {
      if (mounted) {
        final message = error is AuthException &&
                error.message.toLowerCase().contains('password')
                ? 'A senha precisa ter pelo menos 8 caracteres e atingir o nível médio.'
            : 'Não foi possível alterar a senha. Abra novamente o link recebido por e-mail e tente de novo.';
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

  Future<void> _returnToLogin() async {
    setState(() => _busy = true);
    try {
      await ref.read(authViewModelProvider).signOut();
    } catch (error) {
      if (mounted) {
        showFloatingNotice(
          context,
          'A senha foi alterada, mas não foi possível encerrar a sessão: $error',
          type: FloatingSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppTheme.border),
                ),
                child: _updated ? _successContent() : _formContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successContent() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(Icons.check_circle_outline, color: AppTheme.lime, size: 52),
      const SizedBox(height: 16),
      const Text(
        'Senha alterada',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        'Agora entre no MedPlanner com sua nova senha.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.muted),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: _busy ? null : _returnToLogin,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Voltar para o login'),
        ),
      ),
    ],
  );

  Widget _formContent() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Criar nova senha',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Escolha uma senha nova para sua conta.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 22),
        TextFormField(
          controller: _password,
          obscureText: _hidePassword,
          decoration: InputDecoration(
            labelText: 'Nova senha',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _hidePassword ? 'Mostrar senha' : 'Ocultar senha',
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) => value == null || !PasswordPolicy.isAcceptable(value)
              ? 'Use 8 caracteres ou mais e combine tipos diferentes de caracteres.'
              : null,
          onChanged: (_) => setState(() {}),
        ),
        PasswordStrengthIndicator(password: _password.text),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmation,
          obscureText: _hideConfirmation,
          decoration: InputDecoration(
            labelText: 'Confirmar nova senha',
            prefixIcon: const Icon(Icons.lock_reset),
            suffixIcon: IconButton(
              tooltip: _hideConfirmation
                  ? 'Mostrar senha'
                  : 'Ocultar senha',
              onPressed: () =>
                  setState(() => _hideConfirmation = !_hideConfirmation),
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
            if (!_busy) _updatePassword();
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _busy ? null : _updatePassword,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar nova senha'),
          ),
        ),
      ],
    ),
  );
}
