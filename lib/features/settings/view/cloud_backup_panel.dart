import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../viewmodel/cloud_backup_view_model.dart';

class CloudBackupPanel extends ConsumerStatefulWidget {
  const CloudBackupPanel({required this.finance, super.key});

  final FinanceController finance;

  @override
  ConsumerState<CloudBackupPanel> createState() => _CloudBackupPanelState();
}

class _CloudBackupPanelState extends ConsumerState<CloudBackupPanel> {
  bool _busy = false;

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _account(CloudBackupViewModel cloud) async {
    final email = TextEditingController();
    final password = TextEditingController();
    var creating = false;
    var busy = false;
    var message = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(creating ? 'Criar conta na nuvem' : 'Entrar na nuvem'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha'),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(message, style: TextStyle(color: AppTheme.muted)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy
                  ? null
                  : () => setDialogState(() {
                      creating = !creating;
                      message = '';
                    }),
              child: Text(creating ? 'Já tenho conta' : 'Criar conta'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() {
                        busy = true;
                        message = '';
                      });
                      try {
                        final authenticated = creating
                            ? await cloud.signUp(email.text, password.text)
                            : await cloud.signIn(email.text, password.text);
                        if (authenticated) {
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } else {
                          setDialogState(() {
                            busy = false;
                            message =
                                'Conta criada. Confirme o e-mail recebido e depois entre no app.';
                          });
                        }
                      } catch (error) {
                        setDialogState(() {
                          busy = false;
                          message = _authError(error);
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(creating ? 'Criar' : 'Entrar'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    password.dispose();
    if (mounted) setState(() {});
  }

  String _authError(Object error) {
    final message = error is AuthException ? error.message : error.toString();
    if (message.toLowerCase().contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (message.toLowerCase().contains('password')) {
      return 'A senha precisa ter pelo menos 6 caracteres.';
    }
    return message;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _upload(CloudBackupViewModel cloud) async {
    if (!await _confirm(
      title: 'Enviar backup para a nuvem?',
      message:
          'Uma cópia de todos os dados deste aparelho será enviada para sua conta Supabase. Se já houver um backup na nuvem, ele será substituído. Os dados locais serão mantidos.',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await widget.finance.exportAll();
      await cloud.uploadBackup(data);
      _notice('Backup enviado para sua conta Supabase.');
    } catch (error) {
      _notice('Não foi possível enviar o backup: ${_authError(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(CloudBackupViewModel cloud) async {
    if (!await _confirm(
      title: 'Restaurar backup da nuvem?',
      message:
          'Os dados locais deste aparelho serão substituídos pelo último backup salvo na sua conta Supabase.',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await cloud.downloadBackup();
      if (data == null) {
        _notice('Ainda não existe um backup na nuvem.');
        return;
      }
      await widget.finance.restoreAll(data);
      final remindersEnabled = await widget.finance
          .refreshExpenseNotifications();
      _notice(
        remindersEnabled
            ? 'Backup da nuvem restaurado.'
            : 'Backup restaurado. Ative as notificações para receber lembretes.',
      );
    } catch (error) {
      _notice('Não foi possível restaurar o backup: ${_authError(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(supabaseAuthStateProvider);
    final cloud = ref.watch(cloudBackupViewModelProvider);
    final user = cloud.currentUser;
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.cloud_outlined, color: AppTheme.lime),
            title: Text(
              user == null
                  ? 'Conectar conta Supabase'
                  : user.email ?? 'Conta conectada',
            ),
            subtitle: Text(
              user == null
                  ? 'Entre ou crie uma conta para guardar seu backup na nuvem'
                  : 'Conta conectada ao backup seguro na nuvem',
            ),
            trailing: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: user == null ? 'Entrar ou criar conta' : 'Sair',
                    onPressed: () => user == null
                        ? _account(cloud)
                        : cloud.signOut().then((_) {
                            if (mounted) setState(() {});
                          }),
                    icon: Icon(user == null ? Icons.login : Icons.logout),
                  ),
          ),
        ),
        if (user != null) ...[
          Card(
            child: ListTile(
              enabled: !_busy,
              leading: Icon(Icons.cloud_upload_outlined, color: AppTheme.lime),
              title: const Text('Enviar dados locais para a nuvem'),
              subtitle: const Text('Guarda o backup JSON na sua conta'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _upload(cloud),
            ),
          ),
          Card(
            child: ListTile(
              enabled: !_busy,
              leading: Icon(
                Icons.cloud_download_outlined,
                color: AppTheme.lime,
              ),
              title: const Text('Restaurar dados da nuvem'),
              subtitle: const Text('Substitui os dados deste aparelho'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _download(cloud),
            ),
          ),
        ],
      ],
    );
  }
}
