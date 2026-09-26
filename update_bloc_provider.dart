import 'dart:io';

void main() {
  // Update service_locator.dart
  final slFile = File('lib/core/di/service_locator.dart');
  var slContent = slFile.readAsStringSync().replaceAll('\r\n', '\n');
  slContent = '''
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
'''.trimLeft();
  slFile.writeAsStringSync(slContent);

  // Update main.dart
  final mainFile = File('lib/main.dart');
  var mainContent = mainFile.readAsStringSync().replaceAll('\r\n', '\n');
  if (!mainContent.contains("import 'features/home/presentation/bloc/home_bloc.dart';")) {
    mainContent = mainContent.replaceFirst(
      "import 'features/auth/presentation/bloc/auth_bloc.dart';",
      "import 'features/auth/presentation/bloc/auth_bloc.dart';\nimport 'features/home/presentation/bloc/home_bloc.dart';\nimport 'features/home/presentation/bloc/home_event.dart';"
    );
  }
  
  mainContent = mainContent.replaceAll(
    "BlocProvider(create: (context) => sl<AuthBloc>()),",
    "BlocProvider(create: (context) => sl<AuthBloc>()),\n        BlocProvider(create: (context) => sl<HomeBloc>()..add(LoadHomeData())),"
  );
  mainFile.writeAsStringSync(mainContent);

  // Update home_screen.dart (Remove BlocProvider)
  final homeFile = File('lib/features/home/presentation/pages/home_screen.dart');
  var homeContent = homeFile.readAsStringSync().replaceAll('\r\n', '\n');
  
  final oldHome = '''
    return BlocProvider(
      create: (context) => HomeBloc(
        repository: HomeRepository(
          remoteDataSource: HomeRemoteDataSourceImpl(dio: Dio()),
        ),
      )..add(LoadHomeData()),
      child: Scaffold(
'''.trimRight();

  homeContent = homeContent.replaceFirst(oldHome, "    return Scaffold(");
  homeContent = homeContent.replaceFirst(
    '''
          return const SizedBox();
        }
      ),
    );
  }
}
''',
    '''
          return const SizedBox();
        }
      )
    );
  }
}
'''
  );

  homeFile.writeAsStringSync(homeContent);
}
