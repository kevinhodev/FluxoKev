import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class FluxoIaApp extends ConsumerWidget {
  const FluxoIaApp({super.key, this.skipAuthentication = false});

  final bool skipAuthentication;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    if (!skipAuthentication && session.value == null) {
      return MaterialApp(
        title: 'Fluxo IA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const LoginScreen(),
      );
    }
    return MaterialApp.router(
      title: 'Fluxo IA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
