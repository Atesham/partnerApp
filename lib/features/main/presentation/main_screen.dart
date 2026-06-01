import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/order_provider.dart';
import '../../home/presentation/home_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../earnings/presentation/earnings_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  DateTime? _lastBackPressed;

  final List<Widget> _screens = const [
    HomeScreen(),
    OrdersScreen(),
    EarningsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    OrderProvider().listenToOrders();
  }

  Future<bool> _onWillPop() async {
    // If not on home tab, go to home tab first
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }
    // On home tab: double-tap to exit
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Press back again to exit'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4)),
        ],
        border: const Border(top: BorderSide(color: AppTheme.divider, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, current: _index, onTap: (i) => setState(() => _index = i)),
              _NavItem(icon: Icons.inventory_2_rounded, label: 'Orders', index: 1, current: _index, onTap: (i) => setState(() => _index = i)),
              _NavItem(icon: Icons.payments_rounded, label: 'Earnings', index: 2, current: _index, onTap: (i) => setState(() => _index = i)),
              _NavItem(icon: Icons.person_rounded, label: 'Profile', index: 3, current: _index, onTap: (i) => setState(() => _index = i)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final Function(int) onTap;

  const _NavItem({
    required this.icon, required this.label, required this.index,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon, size: 24,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
