import 'package:equatable/equatable.dart';
import '../../data/models/sector_model.dart';
import '../../data/models/sub_sector_model.dart';
import '../../data/models/product_model.dart';

abstract class HomeState extends Equatable {
  const HomeState();
  
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<SectorModel> sectors;
  final List<SubSectorModel> subSectors;
  final List<ProductModel> featuredProducts;
  final List<ProductModel> products;
  final List<String> brands;
  final Map<String, dynamic>? cart;
  final Map<String, dynamic>? wishlist;

  const HomeLoaded({
    required this.sectors,
    required this.subSectors,
    required this.featuredProducts,
    required this.products,
    required this.brands,
    this.cart,
    this.wishlist,
  });

  @override
  List<Object?> get props => [sectors, subSectors, featuredProducts, products, brands, cart, wishlist];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}
