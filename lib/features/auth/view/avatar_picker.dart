import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

String avatarAsset(int index) =>
    'assets/image/avatars/avatar_${index.toString().padLeft(2, '0')}.png';

Future<int?> showAvatarPicker(BuildContext context, int selectedIndex) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppTheme.surface,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Escolha seu avatar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  itemCount: 28,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, item) {
                    final index = item + 1;
                    final selected = index == selectedIndex;
                    return InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: () => Navigator.pop(dialogContext, index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? AppTheme.lime : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            avatarAsset(index),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AvatarPhoto extends StatelessWidget {
  const AvatarPhoto({required this.index, this.radius = 25, super.key});

  final int index;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: AppTheme.surface2,
  backgroundImage: AssetImage(avatarAsset(index.clamp(1, 28).toInt())),
  );
}
