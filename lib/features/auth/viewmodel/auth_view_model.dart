import 'package:supabase_flutter/supabase_flutter.dart';

class AuthViewModel {
  const AuthViewModel(this._client);

  final SupabaseClient _client;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required int avatarIndex,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'avatar_index': avatarIndex},
    );
    return response.session != null;
  }

  Future<void> updateProfile({
    required String fullName,
    required int avatarIndex,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(
        data: {'full_name': fullName.trim(), 'avatar_index': avatarIndex},
      ),
    );
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }
}
