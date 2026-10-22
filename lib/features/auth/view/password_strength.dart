import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

abstract final class PasswordPolicy {
  static const minimumLength = 8;

  static int score(String password) {
    if (password.isEmpty) return 0;
    var points = 0;
    if (password.length >= minimumLength) points++;
    if (password.length >= 12) points++;
    if (RegExp(r'[a-z]').hasMatch(password)) points++;
    if (RegExp(r'[A-Z]').hasMatch(password)) points++;
    if (RegExp(r'\d').hasMatch(password)) points++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) points++;
    return points;
  }

  static bool isAcceptable(String password) =>
      password.length >= minimumLength && score(password) >= 3;

  static String strength(String password) {
    final value = score(password);
    if (password.isEmpty || value <= 2) return 'Fraca';
    if (value <= 4) return 'Média';
    return 'Forte';
  }
}

class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final score = PasswordPolicy.score(password);
    final level = score <= 2 ? 1 : (score <= 4 ? 2 : 3);
    final color = switch (level) {
      1 => Colors.redAccent,
      2 => Colors.orangeAccent,
      _ => AppTheme.lime,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(3, (index) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index == 2 ? 0 : 5),
                      decoration: BoxDecoration(
                        color: index < level ? color : AppTheme.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Senha ${PasswordPolicy.strength(password).toLowerCase()}',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Mínimo de 8 caracteres. Combine letras maiúsculas, minúsculas, números ou símbolos.',
            style: TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
