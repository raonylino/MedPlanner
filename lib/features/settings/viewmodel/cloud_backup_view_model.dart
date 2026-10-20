import 'package:supabase_flutter/supabase_flutter.dart';

class CloudBackupViewModel {
  const CloudBackupViewModel(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<bool> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return response.session != null;
  }

  Future<bool> signUp(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    return response.session != null;
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<bool> hasCloudBackup() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Entre na sua conta primeiro.');
    final row = await _client
        .from('finance_backups')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();
    return row != null;
  }

  Future<void> uploadBackup(
    Map<String, List<Map<String, Object?>>> data,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Entre na sua conta primeiro.');
    await _client.from('finance_backups').upsert({
      'user_id': user.id,
      'data': data,
      'schema_version': 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> downloadBackup() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Entre na sua conta primeiro.');
    final row = await _client
        .from('finance_backups')
        .select('data')
        .eq('user_id', user.id)
        .maybeSingle();
    final data = row?['data'];
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }
}
