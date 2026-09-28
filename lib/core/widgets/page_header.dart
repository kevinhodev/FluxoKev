import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_brand.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    required this.subtitle,
    super.key,
    this.actions = const [],
    this.showBrand = true,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBrand) ...[
          Row(
            children: [
              const AppBrand(compact: true),
              const Spacer(),
              ...actions,
            ],
          ),
          const SizedBox(height: 20),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      ],
    );
  }
}
