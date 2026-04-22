import 'package:business_manager/core/di/app_scope.dart';
import 'package:business_manager/core/theme/app_theme.dart';
import 'package:business_manager/features/auth/presentation/auth_screen.dart';
import 'package:business_manager/features/dashboard/presentation/dashboard_screen.dart';
import 'package:business_manager/features/discounts/presentation/discounts_screen.dart';
import 'package:business_manager/features/expenses/presentation/expenses_screen.dart';
import 'package:business_manager/features/inventory/presentation/inventory_screen.dart';
import 'package:business_manager/features/messages/presentation/messages_screen.dart';
import 'package:business_manager/features/schedule/presentation/schedule_screen.dart';
import 'package:business_manager/shared/models/auth_session.dart';
import 'package:flutter/material.dart';

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
        if (!app.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
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
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final role = app.session!.role;
    final tabs = _tabsForRole(role);
    if (_selectedIndex >= tabs.length) {
      _selectedIndex = 0;
    }

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
        index: _selectedIndex,
        children: tabs.map((tab) => tab.screen).toList(),
      ),
      floatingActionButton: role == UserRole.admin
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const DiscountsScreen()));
              },
              label: const Text('Скидки'),
              icon: const Icon(Icons.percent_rounded),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) => setState(() => _selectedIndex = value),
        destinations: tabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }

  List<_ShellTab> _tabsForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const [
          _ShellTab('Главная', Icons.home_outlined, DashboardScreen()),
          _ShellTab('Сеансы', Icons.calendar_month_outlined, ScheduleScreen()),
          _ShellTab('Склад', Icons.inventory_2_outlined, InventoryScreen()),
          _ShellTab('Расходы', Icons.bar_chart_outlined, ExpensesScreen()),
          _ShellTab('Чат', Icons.message_outlined, MessagesScreen()),
        ];
      case UserRole.performer:
        return const [
          _ShellTab('Главная', Icons.home_outlined, DashboardScreen()),
          _ShellTab('Сеансы', Icons.calendar_month_outlined, ScheduleScreen()),
          _ShellTab('Склад', Icons.inventory_2_outlined, InventoryScreen()),
          _ShellTab('Чат', Icons.message_outlined, MessagesScreen()),
        ];
      case UserRole.user:
        return const [
          _ShellTab('Запись', Icons.calendar_month_outlined, ScheduleScreen()),
          _ShellTab('Чат', Icons.message_outlined, MessagesScreen()),
        ];
    }
  }
}

class _ShellTab {
  const _ShellTab(this.label, this.icon, this.screen);

  final String label;
  final IconData icon;
  final Widget screen;
}
