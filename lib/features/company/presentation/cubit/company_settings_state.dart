part of 'company_settings_cubit.dart';

enum CompanySettingsStatus { initial, loading, loaded, saving, saved, failure }

class CompanySettingsState extends Equatable {
  const CompanySettingsState({
    required this.profile,
    required this.settings,
    this.status = CompanySettingsStatus.initial,
    this.message,
  });

  final CompanyProfile profile;
  final AppSettings settings;
  final CompanySettingsStatus status;
  final String? message;

  bool get isBusy =>
      status == CompanySettingsStatus.loading ||
      status == CompanySettingsStatus.saving;

  CompanySettingsState copyWith({
    CompanyProfile? profile,
    AppSettings? settings,
    CompanySettingsStatus? status,
    String? message,
    bool clearMessage = false,
  }) {
    return CompanySettingsState(
      profile: profile ?? this.profile,
      settings: settings ?? this.settings,
      status: status ?? this.status,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [profile, settings, status, message];
}
