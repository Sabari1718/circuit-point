import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../data/datasources/home_remote_data_source.dart';
import '../../data/repositories/home_repository.dart';
import '../../data/models/product_model.dart';
import '../widgets/product_card.dart';
import 'product_details_screen.dart';

class ProductsScreen extends StatefulWidget {
  final String title;
  final int? categoryId;
  final int? subCategoryId;
  final String? brandName;

  const ProductsScreen({
    super.key,
    required this.title,
    this.categoryId,
    this.subCategoryId,
    this.brandName,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<ProductModel>> _productsFuture;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _sortBy = 'Newest First';
  String _selectedPriceFilter = 'All Prices';
  final List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    final repository = HomeRepository(
      remoteDataSource: HomeRemoteDataSourceImpl(dio: Dio()),
    );
    if (widget.subCategoryId != null) {
      _productsFuture = repository.getProductsBySubCategory(widget.subCategoryId!);
    } else if (widget.categoryId != null) {
      _productsFuture = repository.getProductsByCategory(widget.categoryId!);
    } else if (widget.brandName != null) {
      _productsFuture = repository.getProducts(brand: widget.brandName, limit: 50);
    } else {
        final isSearch = widget.title != 'All Products' && widget.title.isNotEmpty;
        _productsFuture = repository.getProducts(
          limit: 24, 
          search: isSearch ? widget.title : null
        );
      }
  }

  List<ProductModel> _applyFiltersAndSort(List<ProductModel> products) {
    List<ProductModel> filtered = List.from(products);

    // Apply Brand Filter (If title is a brand)
    final brands = ['Hp', 'Maxicom', 'Frontech', 'Ant Esports', 'Dell', 'Zebronics', 'TRUEONE', 'ZOOK'];
    if (brands.contains(widget.title)) {
      filtered = filtered.where((p) => p.brand.toLowerCase() == widget.title.toLowerCase()).toList();
    } 

    // Apply Category Filter
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered.where((p) => _selectedCategories.contains(p.category)).toList();
    }

    // Apply Price Filter
    if (_selectedPriceFilter == 'Under ₹500') {
      filtered = filtered.where((p) => p.offerPrice < 500).toList();
    } else if (_selectedPriceFilter == '₹500 - ₹1,000') {
      filtered = filtered.where((p) => p.offerPrice >= 500 && p.offerPrice <= 1000).toList();
    } else if (_selectedPriceFilter == '₹1,000 - ₹2,500') {
      filtered = filtered.where((p) => p.offerPrice >= 1000 && p.offerPrice <= 2500).toList();
    } else if (_selectedPriceFilter == '₹2,500 - ₹5,000') {
      filtered = filtered.where((p) => p.offerPrice >= 2500 && p.offerPrice <= 5000).toList();
    }

    // Apply Sort
    if (_sortBy == 'Price: Low to High') {
      filtered.sort((a, b) => a.offerPrice.compareTo(b.offerPrice));
    } else if (_sortBy == 'Price: High to Low') {
      filtered.sort((a, b) => b.offerPrice.compareTo(a.offerPrice));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.home, size: 14, color: Colors.grey.shade600),
                Text(' Home / Products / ${widget.title}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
      endDrawer: _buildFilterDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('All Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Discover quality components, sensor modules, and electronics', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          
          // Filters & Sort row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                  icon: const Icon(Icons.tune, size: 16, color: Color(0xFFD32F2F)),
                  label: const Text('Filters', style: TextStyle(color: Color(0xFFD32F2F))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD32F2F)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                Row(
                  children: [
                    const Text('Sort: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: 'Newest First', child: Text('Newest First')),
                        DropdownMenuItem(value: 'Price: Low to High', child: Text('Price: Low to High')),
                        DropdownMenuItem(value: 'Price: High to Low', child: Text('Price: High to Low')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() { _sortBy = val; });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Active Filters Display
          if (widget.title != 'All Products' || _selectedPriceFilter != 'All Prices')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('▼ Active Filters: ', style: TextStyle(color: Color(0xFFD32F2F), fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    if (widget.title != 'All Products')
                      Chip(
                        label: Text(widget.title, style: const TextStyle(fontSize: 10)),
                        backgroundColor: Colors.grey.shade100,
                      ),
                    const SizedBox(width: 8),
                    if (_selectedPriceFilter != 'All Prices')
                      Chip(
                        label: Text(_selectedPriceFilter, style: const TextStyle(fontSize: 10)),
                        backgroundColor: Colors.grey.shade100,
                        deleteIcon: const Icon(Icons.close, size: 12),
                        onDeleted: () {
                          setState(() {
                            _selectedPriceFilter = 'All Prices';
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

          // Grid View
          Expanded(
            child: FutureBuilder<List<ProductModel>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No products found.'));
                }

                final products = _applyFiltersAndSort(snapshot.data!);
                
                if (products.isEmpty) {
                  return const Center(child: Text('No products match your filters.'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.48, // Reduced from 0.52 to ensure NO overflow!
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductCard(
                      title: product.name,
                      brand: product.brand,
                      category: product.category,
                      offerPrice: '₹${product.offerPrice.toInt()}',
                      mrp: 'M.R.P: ₹${product.mrp.toInt()}',
                      discount: 'OFFER',
                      rating: 4.5,
                      imageUrl: product.imageUrl,
                      margin: EdgeInsets.zero,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailsScreen(product: product),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildRadioFilter('All Prices'),
                  _buildRadioFilter('Under ₹500'),
                  _buildRadioFilter('₹500 - ₹1,000'),
                  _buildRadioFilter('₹1,000 - ₹2,500'),
                  _buildRadioFilter('₹2,500 - ₹5,000'),
                  const SizedBox(height: 16),
                  const Text('Custom Range', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildPriceInput('Min')),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
                      Expanded(child: _buildPriceInput('Max')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close drawer
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          minimumSize: const Size(40, 36),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Go', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildCheckboxFilter('Desktop Accessories'),
                  _buildCheckboxFilter('Video Accessories'),
                  _buildCheckboxFilter('Microphone'),
                  _buildCheckboxFilter('Mobile Phone Accessories'),
                  _buildCheckboxFilter('Storage'),
                  _buildCheckboxFilter('Sensors'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('Clear All', style: TextStyle(color: Colors.black)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                      child: const Text('Show Products', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioFilter(String label) {
    bool isSelected = _selectedPriceFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPriceFilter = label;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFD32F2F) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? const Color(0xFFD32F2F) : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxFilter(String label) {
    bool isSelected = _selectedCategories.contains(label);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCategories.remove(label);
          } else {
            _selectedCategories.add(label);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              color: isSelected ? const Color(0xFFD32F2F) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInput(String hint) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          prefixText: '₹ ',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }
}





