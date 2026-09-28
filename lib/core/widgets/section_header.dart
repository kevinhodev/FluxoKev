import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          TextButton.icon(
            onPressed: onAction ?? () {},
            label: Text(action!),
            icon: const Icon(LucideIcons.chevronRight, size: 17),
            iconAlignment: IconAlignment.end,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
      ],
    );
  }
}
