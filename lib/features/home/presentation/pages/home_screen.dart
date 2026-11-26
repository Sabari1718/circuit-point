import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_state.dart';
import '../widgets/category_item.dart';
import '../widgets/product_card.dart';
import 'products_screen.dart';
import 'product_details_screen.dart';
import '../../../../core/app_globals.dart';
import 'cart_screen.dart';
import 'wishlist_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../features/auth/presentation/pages/login_screen.dart';
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const Drawer(child: CartScreen()),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.shade100,
        title: Row(
          children: [
            const Text(
              'VA ',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Groups',
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
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                  }
                }
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(75.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 20.0),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Icon(Icons.search, color: Color(0xFFD32F2F), size: 24),
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search sensors, modules, dev boards...',
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFFF5252)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading || state is HomeInitial) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is HomeError) {
            return Center(child: Text('Error: ${state.message}'));
          } else if (state is HomeLoaded) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // 1. Hero Banner Carousel
            if (state.products.isNotEmpty)
              CarouselSlider(
                options: CarouselOptions(
                  height: 240.0,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 4),
                  enlargeCenterPage: false,
                  viewportFraction: 1.0,
                ),
                items: state.products.take(4).map((product) {
                  return Builder(
                    builder: (BuildContext context) {
                      return Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.pink.shade50, Colors.purple.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      '✨ COMPLETE INVENTORY',
                                      style: TextStyle(
                                        color: Colors.purple,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Everything You Need to Build',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Sensors • Modules • ICs • Displays',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD32F2F),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Shop Electronics', style: TextStyle(fontSize: 10)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    product.imageUrl.isNotEmpty
                                      ? Image.network(product.imageUrl, height: 70, fit: BoxFit.contain)
                                      : const Icon(Icons.image, size: 40, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    Text(
                                      product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '₹${product.offerPrice.toInt()}',
                                          style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '₹${product.mrp.toInt()}',
                                          style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 9),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            // 2. Circular Categories
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  'Sensors', 'Dev Boards', 'Arduino', 'Displays', 'Modules', 
                  'ICs & Chips', 'Power Supplies', 'Cables & Wires', 'Connectors', 'Accessories'
                ].map((category) => InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductsScreen(title: category),
                      ),
                    );
                  },
                  child: CategoryItem(
                    title: category,
                    icon: Icons.memory,
                    bgColor: Colors.pink.shade50,
                    iconColor: Colors.pink,
                  ),
                )).toList(),
              ),
            ),
            
            // 3. Shop by Category (Cards)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Shop by Category',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Explore top electronics categories',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View All Categories (91) →', style: TextStyle(color: Color(0xFFD32F2F), fontSize: 12)),
                  )
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: () {
                  final targetNames = [
                    'Desktop Accessories', 'Video Accessories', 'Microphone',
                    'Mobile Phone Accessories', 'Storage', 'Laptop Spares',
                    'CCTV Recorder', 'Hubs and Ports'
                  ];
                  var filteredSectors = state.sectors.where((s) => targetNames.contains(s.name)).toList();
                  if (filteredSectors.length < 8) {
                    final remaining = state.sectors.where((s) => !targetNames.contains(s.name)).take(8 - filteredSectors.length);
                    filteredSectors.addAll(remaining);
                  }
                  
                  return filteredSectors.take(8).map((sector) {
                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 48) / 2, // 2 items per row
                      child: _buildCategoryCard(context, sector.name, 'Explore items', sector.id),
                    );
                  }).toList();
                }(),
              ),
            ),
            
            const SizedBox(height: 32),
            
            _buildProjectBanner(context),
            
            const SizedBox(height: 32),
            
            // 5. Featured Products
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Featured Products',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Hand-picked components for electronics enthusiasts',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View All Products →', style: TextStyle(color: Color(0xFFD32F2F), fontSize: 12)),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: (state.featuredProducts.isNotEmpty ? state.featuredProducts : state.products.take(6)).map((product) => ProductCard(
                  title: product.name,
                  brand: product.brand,
                  category: product.category,
                  offerPrice: '₹${product.offerPrice.toInt()}',
                  mrp: 'M.R.P: ₹${product.mrp.toInt()}',
                  discount: 'OFFER',
                  rating: 4.5,
                  imageUrl: product.imageUrl,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailsScreen(product: product),
                      ),
                    );
                  },
                )).toList(),
              ),
            ),
            
            const SizedBox(height: 40),
            
            _buildPopularBrands(context, state),
            
            const SizedBox(height: 40),
            
            _buildRecommendedForYou(context, state),
            
            const SizedBox(height: 40),
            
            _buildFooter(),
          ],
        ),
      );
    }
    return const SizedBox();
        },
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, String subtitle, int categoryId) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductsScreen(
              categoryId: categoryId,
              title: title,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder, color: Color(0xFFD32F2F), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Explore',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Icon(Icons.arrow_forward, color: Color(0xFFD32F2F), size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2433), // Dark blue/black
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.settings, color: Color(0xFFE57373), size: 12),
                SizedBox(width: 4),
                Text('PROTOTYPING & HARDWARE', style: TextStyle(color: Color(0xFFE57373), fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Build Your Next Project', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Everything from sensors to development boards ready to ship', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.shopping_bag, size: 16),
                label: const Text('Explore Electronics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              Row(
                children: [
                  _buildBannerIcon(Icons.memory),
                  const SizedBox(width: 8),
                  _buildBannerIcon(Icons.wifi_tethering),
                  const SizedBox(width: 8),
                  _buildBannerIcon(Icons.flash_on),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBannerIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: const Color(0xFFE57373), size: 16),
    );
  }

  Widget _buildPopularBrands(BuildContext context, HomeLoaded state) {
    final brands = state.brands.take(8).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Popular Brands', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Trusted manufacturers & verified component makers', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: brands.map((brand) => InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsScreen(title: brand, brandName: brand)));
              },
              child: Container(
                width: (MediaQuery.of(context).size.width - 44) / 2, // 2 items per row
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: Color(0xFFD32F2F), size: 16),
                        const SizedBox(width: 8),
                        Text(brand, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedForYou(BuildContext context, HomeLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.thumb_up, color: Colors.green, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: const Text(
                            'Recommended For You',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('10 Items', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Explore more popular electronics curated for your projects',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All →', style: TextStyle(color: Color(0xFFD32F2F), fontSize: 12)),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: state.products.take(10).toList().reversed.map((product) => ProductCard(
              title: product.name,
              brand: product.brand,
              category: product.category,
              offerPrice: '₹${product.offerPrice.toInt()}',
              mrp: 'M.R.P: ₹${product.mrp.toInt()}',
              discount: 'OFFER',
              rating: 4.5,
              imageUrl: product.imageUrl,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailsScreen(product: product),
                  ),
                );
              },
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // Trust Badges
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTrustBadge(Icons.verified_user, 'Genuine\nComponents'),
              _buildTrustBadge(Icons.local_shipping, 'Fast\nDelivery'),
              _buildTrustBadge(Icons.security, 'Secure\nPayments'),
              _buildTrustBadge(Icons.assignment_return, 'Easy\nReplacement'),
            ],
          ),
        ),
        
        // Footer Content
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('VA Groups / Voxo Electronics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              const Text('Your premier electronics storefront for authentic sensor modules, development boards, displays, and DIY prototyping components across India.', style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.verified, color: Colors.green, size: 14),
                    SizedBox(width: 8),
                    Expanded(child: Text('100% Circuit Point Assured Genuine Quality', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildFooterLinks('Top Categories', ['Sensor Modules', 'Displays & LCDs', 'Arduino & Dev Boards', 'USB to TTL Modules', 'Relay & Power Modules', 'All Categories →']),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildFooterLinks('Customer Service', ['Browse Catalog', 'My Wishlist', 'Hot Deals & Offers', 'New Arrivals', 'Track Order']),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildFooterLinks('Policies & Support', ['Secure Online Payments', 'Standard 7-Day Replacement', 'Fast Shipping Across India', 'Privacy & Security Guarantee', 'support@srivagroups.in']),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text('© 2026 Voxo / VA Groups. All rights reserved. Built for Makers, Engineers & Creators.', style: TextStyle(color: Colors.grey, fontSize: 10)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFooterBottomBadge(Icons.lock, '256-Bit SSL'),
                  _buildFooterBottomBadge(Icons.local_shipping, 'Fast Dispatch'),
                  _buildFooterBottomBadge(Icons.verified, 'Verified Authentic'),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade700, size: 24),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade700, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ],
    );
  }

  List<Widget> _buildFooterLinks(String title, List<String> links) {
    List<Widget> widgets = [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      const SizedBox(height: 12),
    ];
    widgets.addAll(links.map((link) => Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(link, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    )));
    return widgets;
  }

  Widget _buildFooterBottomBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
      ],
    );
  }
}




