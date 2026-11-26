import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../features/auth/presentation/pages/login_screen.dart';
import 'home_screen.dart';
import 'wishlist_screen.dart';
import 'categories_screen.dart';
import 'cart_screen.dart';
import '../../../../core/app_globals.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const CategoriesScreen(),
    _AccountPage(),
    const WishlistScreen(),
    const CartScreen(),
  ];

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFFD32F2F) : Colors.grey.shade500;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD32F2F).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon, color: color, size: 24),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allows body to extend behind the floating nav bar
      backgroundColor: Colors.white,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
            _buildNavItem(1, Icons.category_outlined, Icons.category, 'Category'),
            _buildNavItem(2, Icons.person_outline, Icons.person, 'Account'),
            _buildNavItem(3, Icons.favorite_border, Icons.favorite, 'Wishlist'),
            _buildNavItem(4, Icons.shopping_cart_outlined, Icons.shopping_cart, 'Cart'),
          ],
        ),
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage();

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Account', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFFD32F2F).withValues(alpha: 0.1),
                      child: const Icon(Icons.person, size: 30, color: Color(0xFFD32F2F)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: AppGlobals.userEmailNotifier,
                        builder: (context, userEmail, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(userEmail == 'Guest' ? 'Guest' : 'User 101', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(userEmail, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Menu Items
              _buildMenuItem(Icons.home_outlined, 'Home', () {}),
              _buildMenuItem(Icons.person_outline, 'My Profile', () {}),
              _buildMenuItem(Icons.shopping_bag_outlined, 'Shop Products', () {}),
              _buildMenuItem(Icons.category_outlined, 'Browse Categories', () {}),
              ValueListenableBuilder(
                valueListenable: AppGlobals.wishlistNotifier,
                builder: (context, wishlist, _) {
                  return _buildMenuItem(Icons.favorite_outline, 'My Wishlist (${wishlist.length})', () {});
                }
              ),
              ValueListenableBuilder(
                valueListenable: AppGlobals.cartNotifier,
                builder: (context, cart, _) {
                  return _buildMenuItem(Icons.shopping_cart_outlined, 'My Cart (${cart.length})', () {});
                }
              ),
              const Divider(height: 32),
              _buildMenuItem(Icons.logout, 'Logout', () => _logout(context), isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.black87),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : Colors.black87, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

