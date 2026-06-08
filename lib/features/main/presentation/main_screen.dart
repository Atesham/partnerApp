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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFF9FAFB), // Match scaffold background precisely for solid, professional look
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
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
          // Floating Bottom Navigation Bar (Zepto/Uber style)
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              index: 0,
              current: _index,
              onTap: (i) => setState(() => _index = i),
            ),
            _NavItem(
              icon: Icons.inventory_2_rounded,
              label: 'Orders',
              index: 1,
              current: _index,
              onTap: (i) => setState(() => _index = i),
            ),
            _NavItem(
              icon: Icons.payments_rounded,
              label: 'Earnings',
              index: 2,
              current: _index,
              onTap: (i) => setState(() => _index = i),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              index: 3,
              current: _index,
              onTap: (i) => setState(() => _index = i),
            ),
          ],
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
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
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
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              // Snappy, clean active indicator dot (instant selection state)
              Container(
                width: isSelected ? 5 : 0,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
