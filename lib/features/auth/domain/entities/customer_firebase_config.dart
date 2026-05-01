import 'package:equatable/equatable.dart';

class CustomerFirebaseConfig extends Equatable {
  const CustomerFirebaseConfig({
    required this.projectId,
    required this.apiKey,
    required this.authDomain,
    required this.storageBucket,
    required this.messagingSenderId,
    required this.appId,
    required this.enabled,
  });

  final String projectId;
  final String apiKey;
  final String authDomain;
  final String storageBucket;
  final String messagingSenderId;
  final String appId;
  final bool enabled;

  @override
  List<Object?> get props => [
    projectId,
    apiKey,
    authDomain,
    storageBucket,
    messagingSenderId,
    appId,
    enabled,
  ];
}
