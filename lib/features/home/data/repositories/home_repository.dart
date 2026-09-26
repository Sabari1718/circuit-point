import '../datasources/home_remote_data_source.dart';
import '../models/sector_model.dart';
import '../models/sub_sector_model.dart';
import '../models/product_model.dart';

class HomeRepository {
  final HomeRemoteDataSource remoteDataSource;

  HomeRepository({required this.remoteDataSource});

  Future<List<SectorModel>> getSectors() => remoteDataSource.getSectors();
  Future<List<SubSectorModel>> getSubSectors() => remoteDataSource.getSubSectors();
  Future<List<ProductModel>> getFeaturedProducts() => remoteDataSource.getFeaturedProducts();
  Future<List<ProductModel>> getProducts({int limit = 24, int page = 1, String? brand, String? search, String? sortBy = 'id', String? sortOrder = 'desc'}) => 
      remoteDataSource.getProducts(limit: limit, page: page, brand: brand, search: search, sortBy: sortBy, sortOrder: sortOrder);
  Future<List<ProductModel>> getProductsBySubCategory(int subCategoryId) => remoteDataSource.getProductsBySubCategory(subCategoryId);
  Future<List<ProductModel>> getProductsByCategory(int categoryId) => remoteDataSource.getProductsByCategory(categoryId);
  Future<List<String>> getBrands() => remoteDataSource.getBrands();
  Future<Map<String, dynamic>> getCart() => remoteDataSource.getCart();
  Future<Map<String, dynamic>> getWishlist() => remoteDataSource.getWishlist();
}



