import 'dart:io';

void main() {
  final file = File('lib/features/home/presentation/pages/product_details_screen.dart');
  var content = file.readAsStringSync().replaceAll('\r\n', '\n');

  content = content.replaceAll(
    '''
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\$action successful!')),
        );
      }
    }
  }
'''.trimRight(),
    '''
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
            SnackBar(content: Text('\${widget.product.name} toggled in wishlist!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('\$action successful!')),
          );
        }
      }
    }
  }
'''.trimRight()
  );

  content = content.replaceAll(
    '''
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.product.name, style: const TextStyle(color: Colors.black, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.shopping_cart_outlined), onPressed: () {}),
        ],
      ),
'''.trimRight(),
    '''
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
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
'''.trimRight()
  );

  content = content.replaceAll(
    '''
                        IconButton(
                          icon: const Icon(Icons.favorite_border, color: Colors.grey),
                          onPressed: () => _checkLoginAndProceed('Wishlist'),
                        ),
'''.trimRight(),
    '''
                        ValueListenableBuilder(
                          valueListenable: AppGlobals.wishlistNotifier,
                          builder: (context, wishlist, _) {
                            final isWishlisted = AppGlobals.isInWishlist(widget.product.id);
                            return IconButton(
                              icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey),
                              onPressed: () => _checkLoginAndProceed('Wishlist'),
                            );
                          }
                        ),
'''.trimRight()
  );

  file.writeAsStringSync(content);
}
