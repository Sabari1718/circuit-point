import 'package:flutter/material.dart';
import '../../data/models/product_model.dart';
import '../../../../features/auth/presentation/pages/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/app_globals.dart';
import 'cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _quantity = 1;
  String _selectedCourier = 'Delhivery';
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedCity;
  String? _selectedArea;

  final List<String> _states = [
    'Karnataka', 'Tamil Nadu', 'Telangana', 'Maharashtra', 'Delhi', 'West Bengal', 'Kerala', 'Gujarat'
  ];
  
  final Map<String, List<String>> _districtsMap = {
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai'],
    'Karnataka': ['Bangalore', 'Mysore', 'Hubli'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur'],
    'Kerala': ['Kochi', 'Trivandrum', 'Kozhikode'],
  };

  final Map<String, List<String>> _citiesMap = {
    'Chennai': ['Adyar', 'T. Nagar', 'Velachery'],
    'Coimbatore': ['Peelamedu', 'Gandhipuram', 'RS Puram'],
    'Madurai': ['Anna Nagar', 'KK Nagar', 'Tallakulam'],
    'Bangalore': ['Koramangala', 'Indiranagar', 'Whitefield'],
  };

  final Map<String, List<String>> _areasMap = {
    'Adyar': ['Area 1', 'Area 2'],
    'T. Nagar': ['Street A', 'Street B'],
    'Velachery': ['Zone 1', 'Zone 2'],
  };

  void _checkLoginAndProceed(String action) async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      if (action == 'Add to Cart' || action == 'Buy Now') {
        AppGlobals.addToCart(widget.product, _quantity);
        if (mounted) {
          Scaffold.of(context).openEndDrawer();
        }
      } else if (action == 'Wishlist') {
        AppGlobals.toggleWishlist(widget.product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${widget.product.name} toggled in wishlist!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$action successful!')),
          );
        }
      }
    }
  }

  void _showEmiPlansDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return const _EmiDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const Drawer(
        child: CartScreen(),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.product.name, style: const TextStyle(color: Colors.black, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          Builder(
            builder: (ctx) => ValueListenableBuilder(
              valueListenable: AppGlobals.cartNotifier,
              builder: (context, cart, _) {
                return IconButton(
                  icon: Badge(
                    isLabelVisible: cart.isNotEmpty,
                    label: Text(cart.length.toString()),
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                );
              }
            )
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Home / Categories / ${widget.product.category.isNotEmpty ? widget.product.category : 'Electronics'} / ${widget.product.name}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),

            // Image
            Container(
              height: 300,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Stack(
                children: [
                  Center(
                    child: widget.product.imageUrl.isNotEmpty
                        ? Image.network(widget.product.imageUrl, fit: BoxFit.contain)
                        : const Icon(Icons.image, size: 100, color: Colors.grey),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('23%\nOFF', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Why Buy & Glance (Left side in web, placed here for mobile)
                  _buildWhyBuyThisProduct(),
                  const SizedBox(height: 16),
                  _buildProductAtAGlance(),
                  const SizedBox(height: 24),

                  // Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD32F2F)), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: const [
                            Icon(Icons.stars, size: 12, color: Color(0xFFD32F2F)),
                            SizedBox(width: 4),
                            Text('CIRCUIT POINT', style: TextStyle(color: Color(0xFFD32F2F), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.check_circle, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text('In Stock & Ready to Ship', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    widget.product.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Ratings
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: const [
                            Text('4.5', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            Icon(Icons.star, color: Colors.white, size: 12),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('154 Ratings & 48 Reviews • 1 views • 28 sold', style: TextStyle(color: Colors.grey, fontSize: 12))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('₹${widget.product.offerPrice.toInt()}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('M.R.P: ₹${widget.product.mrp.toInt()}', style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('You Save ₹209 (23% off) (Inclusive of all taxes)', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                  
                  const SizedBox(height: 24),
                  
                  // Available Offers
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade100)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Offers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        _buildOfferRow('Bank Offer', '10% Instant Discount:', 'Up to ₹1,000 on SBI, HDFC & ICICI Credit Card EMI'),
                        const SizedBox(height: 8),
                        _buildOfferRow('Special Price', 'Extra ₹150 OFF:', 'Get additional savings applied automatically on prepaid UPI'),
                        const SizedBox(height: 8),
                        _buildOfferRow('Partner Offer', 'Flat 15% Cashback:', 'Buy alongside prototyping breadboards / sensors and get 15% reward points'),
                        const SizedBox(height: 8),
                        _buildOfferRow('Free Delivery', 'Free Express Shipping:', 'Standard ground delivery is completely FREE on all catalog orders'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  // EMI Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: const [
                              Icon(Icons.credit_card, size: 16, color: Colors.black54),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('No-cost EMI available from ₹58/month', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _showEmiPlansDialog,
                          child: const Text('View EMI Plans >', style: TextStyle(color: Color(0xFFD32F2F), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Delivery Details
                  const Text('Delivery Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Enter Pincode',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          controller: TextEditingController(text: '560001'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24)),
                        onPressed: () {},
                        child: const Text('Check', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('✅ Delivery available to 560001 • Expected by 27-30 Sept', style: TextStyle(color: Colors.grey, fontSize: 12)),

                  const SizedBox(height: 16),
                  const Divider(),
                  const Center(child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12))),
                  const SizedBox(height: 16),
                  
                  // Select Location
                  Row(
                    children: const [
                      Icon(Icons.location_searching, size: 16),
                      SizedBox(width: 8),
                      Text('Select Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Select your State, District, City, and Area to find physical retail shops with stock nearby:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(child: _buildDropdown(
                        label: 'STATE', 
                        value: _selectedState, 
                        hint: 'Select State',
                        items: _states,
                        onChanged: (val) {
                          setState(() {
                            _selectedState = val;
                            _selectedDistrict = null;
                            _selectedCity = null;
                            _selectedArea = null;
                          });
                        },
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDropdown(
                        label: 'DISTRICT', 
                        value: _selectedDistrict, 
                        hint: 'Select District',
                        items: _selectedState != null ? (_districtsMap[_selectedState!] ?? ['Other']) : [],
                        onChanged: (val) {
                          setState(() {
                            _selectedDistrict = val;
                            _selectedCity = null;
                            _selectedArea = null;
                          });
                        },
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDropdown(
                        label: 'CITY', 
                        value: _selectedCity, 
                        hint: 'Select City',
                        items: _selectedDistrict != null ? (_citiesMap[_selectedDistrict!] ?? ['Other']) : [],
                        onChanged: (val) {
                          setState(() {
                            _selectedCity = val;
                            _selectedArea = null;
                          });
                        },
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDropdown(
                        label: 'AREA', 
                        value: _selectedArea, 
                        hint: 'Select Area',
                        items: _selectedCity != null ? (_areasMap[_selectedCity!] ?? ['Other']) : [],
                        onChanged: (val) {
                          setState(() => _selectedArea = val);
                        },
                      )),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade100)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.warning, color: Colors.red, size: 16),
                            SizedBox(width: 4),
                            Text('Unable to load data.', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            minimumSize: const Size(60, 24),
                            backgroundColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.refresh, size: 14, color: Colors.black),
                              SizedBox(width: 4),
                              Text('Retry', style: TextStyle(color: Colors.black, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Select Courier Partner
                  const Text('SELECT COURIER PARTNER:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCourierCard('Delhivery', 'By Mon, 28 Sept', 'FREE Delivery', true),
                        const SizedBox(width: 8),
                        _buildCourierCard('Blue Dart', 'By Sun, 27 Sept', '₹40 Express', false),
                        const SizedBox(width: 8),
                        _buildCourierCard('DTDC', 'By Tue, 29 Sept', 'FREE Delivery', false),
                        const SizedBox(width: 8),
                        _buildCourierCard('Ecom', 'By Wed, 30 Sept', 'FREE Delivery', false),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      children: const [
                        Icon(Icons.payments, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text('Cash on Delivery (COD) Available', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Circuit Point Assured
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.security, color: Colors.green),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Circuit Point Assured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('100% Genuine, Verified Quality & Safe Delivery', style: TextStyle(color: Colors.grey, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildAssuredItem('100% Genuine & Brand-Certified')),
                            Expanded(child: _buildAssuredItem('Bench-Tested & Quality Inspected')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildAssuredItem('7-Day Easy Replacement Policy')),
                            Expanded(child: _buildAssuredItem('Dedicated Hardware Tech Support')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildAssuredItem('Anti-Static Protective Packaging')),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Quantity: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            if (_quantity > 1) setState(() => _quantity--);
                          },
                          child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('-', style: TextStyle(fontSize: 16)))),
                        Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
                        InkWell(
                          onTap: () {
                            setState(() => _quantity++);
                          },
                          child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('+', style: TextStyle(fontSize: 16)))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD32F2F)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _checkLoginAndProceed('Add to Cart'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart, color: Color(0xFFD32F2F), size: 18),
                          const SizedBox(width: 8),
                          Text('Add to Cart ($_quantity)', style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _checkLoginAndProceed('Buy Now'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.flash_on, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text('Buy Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.favorite_border, color: Colors.grey),
                      onPressed: () => _checkLoginAndProceed('Wishlist'),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhyBuyThisProduct() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_user_outlined, size: 16),
              SizedBox(width: 8),
              Text('WHY BUY THIS PRODUCT?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildWhyBuyItem('Genuine Product', '100% authentic component')),
              Expanded(child: _buildWhyBuyItem('Quality Checked', 'Multi-point bench tested')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildWhyBuyItem('Fast Delivery', 'Express 24h dispatch')),
              Expanded(child: _buildWhyBuyItem('Secure Payment', '256-bit encrypted checkout')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildWhyBuyItem('Warranty Support', '1-Year replacement coverage')),
              Expanded(child: _buildWhyBuyItem('Easy Replacement', '7-day doorstep return')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductAtAGlance() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.list_alt, size: 16),
              SizedBox(width: 8),
              Text('PRODUCT AT A GLANCE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          _buildGlanceRow('Brand', widget.product.brand.isNotEmpty ? widget.product.brand : 'Circuit Point'),
          const Divider(),
          _buildGlanceRow('Category', widget.product.category.isNotEmpty ? widget.product.category : 'Electronics'),
          const Divider(),
          _buildGlanceRow('Availability', 'In Stock (50 Units)'),
          const Divider(),
          _buildGlanceRow('Warranty', '1 Year Seller Warranty'),
          const Divider(),
          _buildGlanceRow('Delivery', 'Available across India (2-4 Days)'),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label, 
    required String? value, 
    required String hint, 
    required List<String> items, 
    required Function(String?) onChanged
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text(hint, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
              onChanged: items.isEmpty ? null : onChanged,
              items: items.map<DropdownMenuItem<String>>((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferRow(String tag, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
          child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              children: [
                TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourierCard(String name, String date, String price, bool isDefault) {
    bool isSelected = _selectedCourier == name;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCourier = name;
        });
      },
      child: Container(
        width: 140, // Match screenshot style with fixed width for each card
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? const Color(0xFFD32F2F) : Colors.grey.shade300, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: isSelected ? const Color(0xFFD32F2F) : Colors.grey),
              ],
            ),
            const SizedBox(height: 4),
            Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(price, style: TextStyle(fontSize: 10, color: price.contains('FREE') ? Colors.green : Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildWhyBuyItem(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF0F172A), size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssuredItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 12),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildGlanceRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _EmiDialog extends StatefulWidget {
  const _EmiDialog();
  @override
  State<_EmiDialog> createState() => _EmiDialogState();
}

class _EmiDialogState extends State<_EmiDialog> {
  String _selectedBank = 'HDFC Bank';
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.credit_card, color: Colors.pink, size: 24),
                    SizedBox(width: 8),
                    Text('EMI Payment Plans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
            const Text('Flexible No-Cost & Low-Cost monthly installment options for ₹699', style: TextStyle(color: Colors.grey, fontSize: 10)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildBankTab('HDFC Bank'),
                  _buildBankTab('ICICI Bank'),
                  _buildBankTab('State Bank of India'),
                  _buildBankTab('Axis Bank', noCost: false),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: Colors.grey.shade50,
                    child: Row(
                      children: const [
                        Expanded(flex: 2, child: Text('Tenure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                        Expanded(flex: 2, child: Text('Monthly Installment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                        Expanded(flex: 2, child: Text('Interest Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                        Expanded(flex: 2, child: Text('Total Cost', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  _buildEmiRow('3 Months', '₹233/mo', '0% (No Interest)', '₹699', isNoCost: true),
                  const Divider(height: 1),
                  _buildEmiRow('6 Months', '₹117/mo', '0% (No Interest)', '₹699', isNoCost: true),
                  const Divider(height: 1),
                  _buildEmiRow('9 Months', '₹82/mo', '13.5% p.a.', '₹738(+₹39 interest)', isNoCost: false),
                  const Divider(height: 1),
                  _buildEmiRow('12 Months', '₹63/mo', '14% p.a.', '₹756(+₹57 interest)', isNoCost: false),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('ℹ️ No-cost EMI is available on select Credit Cards & Bajaj Finserv cards. Processing fees may be levied directly by the issuing bank at checkout.', style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildBankTab(String name, {bool noCost = true}) {
    bool isSelected = _selectedBank == name;
    return GestureDetector(
      onTap: () => setState(() => _selectedBank = name),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD32F2F) : Colors.white,
          border: Border.all(color: isSelected ? const Color(0xFFD32F2F) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Text(name, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
            if (noCost) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(2)),
                child: const Text('No Cost EMI', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildEmiRow(String tenure, String emi, String interest, String total, {bool isNoCost = false}) {
    return Container(
      color: isNoCost ? Colors.green.shade50 : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tenure, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
              if (isNoCost)
                const Text('No Cost', style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          )),
          Expanded(flex: 2, child: Text(emi, style: const TextStyle(fontSize: 10))),
          Expanded(flex: 2, child: Text(interest, style: const TextStyle(fontSize: 10))),
          Expanded(flex: 2, child: Text(total, style: const TextStyle(fontSize: 10))),
        ],
      ),
    );
  }
}




