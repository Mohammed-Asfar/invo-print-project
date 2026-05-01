import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/admin_setup_repository.dart';

part 'admin_setup_state.dart';

class AdminSetupCubit extends Cubit<AdminSetupState> {
  AdminSetupCubit(this._repository) : super(const AdminSetupInitial());

  final AdminSetupRepository _repository;

  Future<void> save(CustomerSetupInput input) async {
    emit(const AdminSetupSaving());
    try {
      await _repository.createOrUpdateCustomerSetup(input);
      emit(const AdminSetupSaved());
    } catch (error) {
      emit(AdminSetupFailure(error.toString()));
    }
  }
}
