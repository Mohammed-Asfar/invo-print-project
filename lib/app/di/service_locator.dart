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
import '../../features/customers/data/repositories/customer_repository.dart';
import '../../features/customers/presentation/cubit/customer_cubit.dart';
import '../../features/invoices/data/repositories/invoice_repository.dart';
import '../../features/invoices/domain/services/invoice_calculator.dart';
import '../../features/invoices/presentation/cubit/invoice_cubit.dart';
import '../../features/products/data/repositories/product_repository.dart';
import '../../features/products/presentation/cubit/product_cubit.dart';
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
    ..registerLazySingleton<CustomerRepository>(
      () => CustomerRepository(sl<CustomerFirestoreRestClient>()),
    )
    ..registerLazySingleton<ProductRepository>(
      () => ProductRepository(sl<CustomerFirestoreRestClient>()),
    )
    ..registerLazySingleton<InvoiceRepository>(
      () => InvoiceRepository(sl<CustomerFirestoreRestClient>()),
    )
    ..registerLazySingleton<InvoiceCalculator>(InvoiceCalculator.new)
    ..registerLazySingleton<NumberingService>(NumberingService.new)
    ..registerFactory(() => AdminSetupCubit(sl<AdminSetupRepository>()))
    ..registerFactory(
      () => CompanySettingsCubit(sl<CompanySettingsRepository>()),
    )
    ..registerFactory(
      () => CustomerCubit(
        sl<CustomerRepository>(),
        sl<CompanySettingsRepository>(),
      ),
    )
    ..registerFactory(() => ProductCubit(sl<ProductRepository>()))
    ..registerFactory(
      () => InvoiceCubit(
        sl<InvoiceRepository>(),
        sl<CustomerRepository>(),
        sl<ProductRepository>(),
        sl<CompanySettingsRepository>(),
        sl<InvoiceCalculator>(),
        sl<NumberingService>(),
      ),
    )
    ..registerLazySingleton<ThemeCubit>(ThemeCubit.new)
    ..registerFactory(() => AuthBloc(sl<AuthRepository>()));
}
