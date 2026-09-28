import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            destinations: const [
              NavigationDestination(
                icon: Icon(LucideIcons.home),
                label: 'Visão Geral',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.calendarClock),
                label: 'Compromissos',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.target),
                label: 'Planejamento',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.messageCircle),
                label: 'Chat com IA',
              ),
              NavigationDestination(
                icon: Icon(LucideIcons.layoutGrid),
                label: 'Mais',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
