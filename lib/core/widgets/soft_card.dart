import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.radius = 18,
    this.borderColor = AppColors.border,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B111827),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: content,
    );
  }
}
