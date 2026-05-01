import 'package:equatable/equatable.dart';

class AdminSession extends Equatable {
  const AdminSession({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  final String uid;
  final String email;
  final String displayName;

  @override
  List<Object?> get props => [uid, email, displayName];
}
