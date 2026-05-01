import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../company/data/repositories/company_settings_repository.dart';
import '../../../company/domain/entities/app_settings.dart';
import '../../data/repositories/customer_repository.dart';
import '../../domain/entities/customer.dart';

part 'customer_state.dart';

class CustomerCubit extends Cubit<CustomerState> {
  CustomerCubit(this._repository, this._settingsRepository)
    : super(const CustomerState());

  final CustomerRepository _repository;
  final CompanySettingsRepository _settingsRepository;

  Future<void> load() async {
    emit(state.copyWith(status: CustomerStatus.loading));
    try {
      final results = await Future.wait<Object>([
        _repository.fetchCustomers(),
        _settingsRepository.fetchAppSettings(),
      ]);
      final customers = results[0] as List<Customer>;
      final settings = results[1] as AppSettings;
      emit(
        state.copyWith(
          status: CustomerStatus.loaded,
          customers: customers,
          globalLoyaltyEnabled: settings.loyaltyEnabled,
          clearMessage: true,
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(status: CustomerStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: CustomerStatus.failure,
          message: 'Unable to load customers: $error',
        ),
      );
    }
  }

  void search(String value) {
    emit(state.copyWith(searchQuery: value));
  }

  Future<void> save(Customer customer) async {
    emit(state.copyWith(status: CustomerStatus.saving));
    try {
      await _repository.saveCustomer(
        state.globalLoyaltyEnabled ? customer : _withLoyaltyDisabled(customer),
      );
      final customers = await _repository.fetchCustomers();
      emit(
        state.copyWith(
          status: CustomerStatus.saved,
          customers: customers,
          message: 'Customer saved.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(status: CustomerStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: CustomerStatus.failure,
          message: 'Unable to save customer: $error',
        ),
      );
    }
  }

  Customer _withLoyaltyDisabled(Customer customer) {
    return Customer(
      id: customer.id,
      name: customer.name,
      phone: customer.phone,
      email: customer.email,
      billingAddress: customer.billingAddress,
      shippingAddress: customer.shippingAddress,
      gstin: customer.gstin,
      state: customer.state,
      defaultDiscountType: customer.defaultDiscountType,
      defaultDiscountValue: customer.defaultDiscountValue,
      loyaltyEnabled: false,
      loyaltyPointsBalance: customer.loyaltyPointsBalance,
      lifetimePointsEarned: customer.lifetimePointsEarned,
      lifetimePointsRedeemed: customer.lifetimePointsRedeemed,
      totalBilled: customer.totalBilled,
      totalPaid: customer.totalPaid,
      outstandingAmount: customer.outstandingAmount,
      lastInvoiceAt: customer.lastInvoiceAt,
      notes: customer.notes,
      isActive: customer.isActive,
      createdAt: customer.createdAt,
      updatedAt: customer.updatedAt,
    );
  }

  Future<void> archive(Customer customer) async {
    emit(state.copyWith(status: CustomerStatus.saving));
    try {
      await _repository.archiveCustomer(customer);
      final customers = await _repository.fetchCustomers();
      emit(
        state.copyWith(
          status: CustomerStatus.saved,
          customers: customers,
          message: 'Customer archived.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(status: CustomerStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: CustomerStatus.failure,
          message: 'Unable to archive customer: $error',
        ),
      );
    }
  }
}
