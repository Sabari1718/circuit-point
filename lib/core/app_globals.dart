import 'package:flutter/foundation.dart';
import '../features/home/data/models/product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class AppGlobals {
  static final ValueNotifier<List<CartItem>> cartNotifier = ValueNotifier([]);
  static final ValueNotifier<List<ProductModel>> wishlistNotifier = ValueNotifier([]);
  static final ValueNotifier<String> userEmailNotifier = ValueNotifier('Guest');

  static void addToCart(ProductModel product, int quantity) {
    final current = List<CartItem>.from(cartNotifier.value);
    final existingIndex = current.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      current[existingIndex].quantity += quantity;
    } else {
      current.add(CartItem(product: product, quantity: quantity));
    }
    cartNotifier.value = current;
  }

  static void removeFromCart(String productId) {
    final current = List<CartItem>.from(cartNotifier.value);
    current.removeWhere((item) => item.product.id == productId);
    cartNotifier.value = current;
  }

  static double get cartTotal {
    return cartNotifier.value.fold(0, (sum, item) => sum + (item.product.offerPrice * item.quantity));
  }

  static void toggleWishlist(ProductModel product) {
    final current = List<ProductModel>.from(wishlistNotifier.value);
    final exists = current.any((p) => p.id == product.id);
    if (exists) {
      current.removeWhere((p) => p.id == product.id);
    } else {
      current.add(product);
    }
    wishlistNotifier.value = current;
  }

  static bool isInWishlist(String productId) {
    return wishlistNotifier.value.any((p) => p.id == productId);
  }
}
