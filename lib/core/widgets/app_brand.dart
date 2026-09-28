import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

class AppBrand extends StatelessWidget {
  const AppBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.sparkles,
            color: Colors.white,
            size: compact ? 20 : 24,
          ),
        ),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            children: const [
              TextSpan(text: 'Fluxo '),
              TextSpan(
                text: 'IA',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 22 : 26,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }
}
