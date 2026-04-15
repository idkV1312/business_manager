import 'package:flutter/material.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/discounts/presentation/discounts_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../di/app_scope.dart';
import '../navigation/app_tab.dart';
import '../theme/app_theme.dart';

class StudioApp extends StatelessWidget {
  const StudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pulse Studio',
      theme: AppTheme.light(),
      home: const _Gate(),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (!app.isAuthenticated) {
          return const AuthScreen();
        }
        return const _RootShell();
      },
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  AppTab _tab = AppTab.dashboard;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Выйти',
            onPressed: app.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _tab.index,
        children: const [
          DashboardScreen(),
          ScheduleScreen(),
          InventoryScreen(),
          ExpensesScreen(),
          MessagesScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DiscountsScreen()),
          );
        },
        label: const Text('Скидки'),
        icon: const Icon(Icons.percent_rounded),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (value) => setState(() => _tab = AppTab.values[value]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Сеансы'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Товары'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Расходы'),
          NavigationDestination(icon: Icon(Icons.message_outlined), label: 'Чат'),
        ],
      ),
    );
  }
}
