import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/commitments/presentation/commitments_screen.dart';
import '../../features/document_imports/presentation/document_import_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/overview/presentation/overview_screen.dart';
import '../../features/pension/presentation/pension_projection_screen.dart';
import '../../features/planning/presentation/planning_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../../features/transactions/presentation/automation_rules_screen.dart';
import '../shell/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/overview',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/overview',
              builder: (context, state) => const OverviewScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/commitments',
              builder: (context, state) => CommitmentsScreen(
                initialSection: switch (state.uri.queryParameters['section']) {
                  'subscriptions' => 1,
                  'fixed' => 2,
                  _ => 0,
                },
              ),
              routes: [
                GoRoute(
                  path: 'transactions',
                  builder: (context, state) => const TransactionsScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/planning',
              builder: (context, state) => const PlanningScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (context, state) => const MoreScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/rules',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AutomationRulesScreen(),
    ),
    GoRoute(
      path: '/imports',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DocumentImportScreen(),
    ),
    GoRoute(
      path: '/pension/:pensionId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => PensionProjectionScreen(
        pensionId: state.pathParameters['pensionId']!,
      ),
    ),
  ],
);
