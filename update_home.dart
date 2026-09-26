import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/home_screen.dart');
  var content = file.readAsStringSync().replaceAll('\r\n', '\n');

  // Add imports if they don't exist
  if (!content.contains("import '../../../../core/app_globals.dart';")) {
    content = content.replaceFirst(
      "import 'product_details_screen.dart';",
      "import 'product_details_screen.dart';\nimport '../../../../core/app_globals.dart';\nimport 'cart_screen.dart';\nimport 'wishlist_screen.dart';\nimport 'package:shared_preferences/shared_preferences.dart';\nimport '../../../../features/auth/presentation/pages/login_screen.dart';"
    );
  }

  // Replace Scaffold
  content = content.replaceAll(
    '''
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Voxo ',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            Text(
              'VA Groups',
              style: TextStyle(
                color: const Color(0xFFD32F2F),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.black87),
            onPressed: () {},
          ),
        ],
'''.trimRight(),
    '''
      child: Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const Drawer(child: CartScreen()),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.shade100,
        title: Row(
          children: [
            const Text(
              'Circuit ',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Point',
              style: TextStyle(
                color: const Color(0xFFD32F2F),
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: AppGlobals.wishlistNotifier,
            builder: (context, wishlist, _) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: wishlist.isNotEmpty,
                  label: Text(wishlist.length.toString()),
                  child: const Icon(Icons.favorite_border, color: Colors.black87),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()));
                },
              );
            }
          ),
          Builder(
            builder: (ctx) => ValueListenableBuilder(
              valueListenable: AppGlobals.cartNotifier,
              builder: (context, cart, _) {
                return IconButton(
                  icon: Badge(
                    isLabelVisible: cart.isNotEmpty,
                    label: Text(cart.length.toString()),
                    child: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
                  ),
                  onPressed: () {
                    Scaffold.of(ctx).openEndDrawer();
                  },
                );
              }
            )
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.person_outline, color: Colors.black87),
              itemBuilder: (context) {
                return [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: ValueListenableBuilder<String>(
                      valueListenable: AppGlobals.userEmailNotifier,
                      builder: (context, userEmail, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userEmail == 'Guest' ? 'Guest' : 'User 101', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                            Text(userEmail, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            const Divider(),
                          ],
                        );
                      }
                    ),
                  ),
                  const PopupMenuItem(value: 'home', child: ListTile(leading: Icon(Icons.home_outlined, size: 20), title: Text('Home'), dense: true, contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'profile', child: ListTile(leading: Icon(Icons.person_outline, size: 20), title: Text('My Profile'), dense: true, contentPadding: EdgeInsets.zero)),
                  const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout, size: 20, color: Colors.red), title: Text('Logout', style: TextStyle(color: Colors.red)), dense: true, contentPadding: EdgeInsets.zero)),
                ];
              },
              onSelected: (value) async {
                if (value == 'logout') {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isLoggedIn', false);
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                }
              },
            ),
          ),
        ],
'''.trimRight()
  );

  file.writeAsStringSync(content);
}
