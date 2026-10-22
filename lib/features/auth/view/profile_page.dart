import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/ui.dart';
import 'avatar_picker.dart';
import 'password_strength.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _profileKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  int _avatarIndex = 1;
  bool _savingProfile = false;
  bool _savingPassword = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    _name.text = metadata['full_name']?.toString() ?? '';
    _avatarIndex = int.tryParse(metadata['avatar_index']?.toString() ?? '') ?? 1;
  }

  @override
  void dispose() {
    _name.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _notice(String message) {
    showFloatingNotice(context, message);
  }

  String _errorMessage(Object error) {
    final message = error is AuthException ? error.message : error.toString();
    if (message.toLowerCase().contains('password')) {
      return 'A senha precisa ter pelo menos 8 caracteres e atingir o nível médio.';
    }
    return message;
  }

  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      await ref.read(authViewModelProvider).updateProfile(
        fullName: _name.text,
        avatarIndex: _avatarIndex,
      );
      _notice('Perfil atualizado.');
    } catch (error) {
      _notice('Não foi possível atualizar o perfil: ${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    final password = _newPassword.text;
    if (!PasswordPolicy.isAcceptable(password)) {
      _notice('Use 8 caracteres ou mais e combine tipos diferentes de caracteres.');
      return;
    }
    if (password != _confirmPassword.text) {
      _notice('As senhas não conferem.');
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await ref.read(authViewModelProvider).updatePassword(password);
      _newPassword.clear();
      _confirmPassword.clear();
      _notice('Senha alterada.');
    } catch (error) {
      _notice('Não foi possível alterar a senha: ${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(supabaseAuthStateProvider);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                AvatarPhoto(index: _avatarIndex, radius: 48),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final selected = await showAvatarPicker(
                      context,
                      _avatarIndex,
                    );
                    if (selected != null && mounted) {
                      setState(() => _avatarIndex = selected);
                    }
                  },
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Alterar avatar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _profileKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe seu nome.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: user?.email ?? '',
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    helperText: 'O e-mail não pode ser alterado por aqui.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _savingProfile ? null : _saveProfile,
            child: _savingProfile
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar perfil'),
          ),
          const SizedBox(height: 28),
          const Text(
            'Alterar senha',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _newPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nova senha'),
            onChanged: (_) => setState(() {}),
          ),
          PasswordStrengthIndicator(password: _newPassword.text),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirmar nova senha'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _savingPassword ? null : _savePassword,
            child: _savingPassword
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Alterar senha', style: TextStyle(color: AppTheme.text)),
          ),
        ],
      ),
    );
  }
}
