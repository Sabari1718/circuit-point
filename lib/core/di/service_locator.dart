import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import '../network/api_client.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';
import '../../features/home/data/repositories/home_repository.dart';
import '../../features/home/data/datasources/home_remote_data_source.dart';

final sl = GetIt.instance;

Future<void> setupLocator() async {
  sl.registerLazySingleton<ApiClient>(() => ApiClient(Dio()));
  
  sl.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(dio: Dio()),
  );
  
  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepository(remoteDataSource: sl()),
  );
  
  sl.registerFactory<AuthBloc>(() => AuthBloc());
  sl.registerFactory<HomeBloc>(() => HomeBloc(repository: sl()));
}
