import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Ink(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 19),
                const SizedBox(width: 9),
              ],
              if (expand)
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}
