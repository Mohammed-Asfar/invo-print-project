import 'package:get_it/get_it.dart';

import '../../core/firebase/control_firestore_rest_client.dart';
import '../../core/firebase/customer_firestore_rest_client.dart';
import '../../core/firebase/firebase_app_manager.dart';
import '../../features/admin_setup/data/repositories/admin_setup_repository.dart';
import '../../features/admin_setup/presentation/cubit/admin_setup_cubit.dart';
import '../../features/auth/data/repositories/firebase_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/company/data/repositories/company_settings_repository.dart';
import '../../features/company/presentation/cubit/company_settings_cubit.dart';
import '../theme/theme_cubit.dart';

final sl = GetIt.instance;

void setupServiceLocator() {
  sl
    ..registerLazySingleton<FirebaseAppManager>(FirebaseAppManager.new)
    ..registerLazySingleton<ControlFirestoreRestClient>(
      () => ControlFirestoreRestClient(sl<FirebaseAppManager>()),
    )
    ..registerLazySingleton<CustomerFirestoreRestClient>(
      () => CustomerFirestoreRestClient(sl<FirebaseAppManager>()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => FirebaseAuthRepository(
        sl<FirebaseAppManager>(),
        sl<ControlFirestoreRestClient>(),
      ),
    )
    ..registerLazySingleton<AdminSetupRepository>(
      () => AdminSetupRepository(sl<ControlFirestoreRestClient>()),
    )
    ..registerLazySingleton<CompanySettingsRepository>(
      () => CompanySettingsRepository(sl<CustomerFirestoreRestClient>()),
    )
    ..registerFactory(() => AdminSetupCubit(sl<AdminSetupRepository>()))
    ..registerFactory(
      () => CompanySettingsCubit(sl<CompanySettingsRepository>()),
    )
    ..registerLazySingleton<ThemeCubit>(ThemeCubit.new)
    ..registerFactory(() => AuthBloc(sl<AuthRepository>()));
}
