import 'package:dio/dio.dart';
import '../models/sector_model.dart';
import '../models/sub_sector_model.dart';
import '../models/product_model.dart';

abstract class HomeRemoteDataSource {
  Future<List<SectorModel>> getSectors();
  Future<List<SubSectorModel>> getSubSectors();
  Future<List<ProductModel>> getFeaturedProducts();
  Future<List<ProductModel>> getProducts({int limit = 24, int page = 1, String? brand, String? search, String? sortBy = 'id', String? sortOrder = 'desc'});
  Future<List<ProductModel>> getProductsByCategory(int categoryId);
  Future<List<ProductModel>> getProductsBySubCategory(int subCategoryId);
  Future<List<String>> getBrands();
  Future<Map<String, dynamic>> getCart();
  Future<Map<String, dynamic>> getWishlist();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final Dio dio;

  HomeRemoteDataSourceImpl({required this.dio});

  List<dynamic> _extractList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      if (data['data'] is List) return data['data'];
      if (data['data'] is Map && data['data']['data'] is List) return data['data']['data'];
      if (data['items'] is List) return data['items'];
      if (data['products'] is List) return data['products'];
      for (var value in data.values) {
        if (value is List) return value;
      }
    }
    return [];
  }

  @override
  Future<List<SectorModel>> getSectors() async {
    final response = await dio.get('https://rtest.epriceoffer.com/api/sectors');
    if (response.statusCode == 200) {
      final list = _extractList(response.data);
      return list.map((e) => SectorModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load sectors');
    }
  }

  @override
  Future<List<SubSectorModel>> getSubSectors() async {
    final response = await dio.get('https://rtest.epriceoffer.com/api/sub-sectors');
    if (response.statusCode == 200) {
      final list = _extractList(response.data);
      return list.map((e) => SubSectorModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load sub-sectors');
    }
  }

  @override
  Future<List<ProductModel>> getFeaturedProducts() async {
    final response = await dio.get('https://rtest.epriceoffer.com/api/products/featured');
    if (response.statusCode == 200) {
      final list = _extractList(response.data);
      return list.map((e) => ProductModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load featured products');
    }
  }

  @override
  Future<List<ProductModel>> getProducts({int limit = 24, int page = 1, String? brand, String? search, String? sortBy = 'id', String? sortOrder = 'desc'}) async {
    String url = 'https://rtest.epriceoffer.com/api/products?page=$page&limit=$limit&sort_by=$sortBy&sort_order=$sortOrder';
    if (brand != null && brand.isNotEmpty) {
      url += '&brands=$brand';
    }
    final response = await dio.get(url);
    if (response.statusCode == 200) {
      final list = _extractList(response.data);
      return list.map((e) => ProductModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load products');
    }
  }

  @override
  Future<List<ProductModel>> getProductsBySubCategory(int subCategoryId) async {
    final response = await dio.get('https://rtest.epriceoffer.com/api/products?sub_category_id=$subCategoryId');
    if (response.statusCode == 200) {
      final list = _extractList(response.data);
      return list.map((e) => ProductModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load products for sub-category');
    }
  }

  @override
  Future<List<ProductModel>> getProductsByCategory(int categoryId) async {
    final response = await dio.get('https://rtest.epriceoffer.com/api/products?category_id=$categoryId');
    if (response.statusCode == 200) {
      final list = _extractList(response.data);
      return list.map((e) => ProductModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load products for category');
    }
  }

  @override
  Future<List<String>> getBrands() async {
    final response = await dio.get('https://rtest.epriceoffer.com/api/brands');
    if (response.statusCode == 200) {
      final list = _extractList(response.data);
      return list.map((e) => e.toString()).toList();
    } else {
      throw Exception('Failed to load brands');
    }
  }

  @override
  Future<Map<String, dynamic>> getCart() async {
    final response = await dio.get('https://rtest.epriceoffer.com/api/cart');
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to load cart');
    }
  }

  @override
  Future<Map<String, dynamic>> getWishlist() async {
    final response = await dio.get('https://rtest.epriceoffer.com/api/wishlist');
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to load wishlist');
    }
  }
}


