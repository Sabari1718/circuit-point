import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_event.dart';
import 'home_state.dart';
import '../../data/repositories/home_repository.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeRepository repository;

  HomeBloc({required this.repository}) : super(HomeInitial()) {
    on<LoadHomeData>(_onLoadHomeData);
  }

  Future<void> _onLoadHomeData(LoadHomeData event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    try {
      final sectors = await repository.getSectors();
      final subSectors = await repository.getSubSectors();
      final featuredProducts = await repository.getFeaturedProducts();
      final products = await repository.getProducts(limit: 5000);
      final brands = await repository.getBrands();
      
      Map<String, dynamic>? cart;
      Map<String, dynamic>? wishlist;
      try {
        cart = await repository.getCart();
      } catch (_) {}
      try {
        wishlist = await repository.getWishlist();
      } catch (_) {}

      emit(HomeLoaded(
        sectors: sectors,
        subSectors: subSectors,
        featuredProducts: featuredProducts,
        products: products,
        brands: brands,
        cart: cart,
        wishlist: wishlist,
      ));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }
}

