part of 'admin_setup_cubit.dart';

sealed class AdminSetupState extends Equatable {
  const AdminSetupState();

  @override
  List<Object?> get props => [];
}

class AdminSetupInitial extends AdminSetupState {
  const AdminSetupInitial();
}

class AdminSetupSaving extends AdminSetupState {
  const AdminSetupSaving();
}

class AdminSetupSaved extends AdminSetupState {
  const AdminSetupSaved();
}

class AdminSetupFailure extends AdminSetupState {
  const AdminSetupFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
