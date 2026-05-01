class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MissingFirebaseConfigException extends AppException {
  const MissingFirebaseConfigException()
    : super(
        'Control Firebase config is missing. Start the app with the required --dart-define values.',
      );
}

class SetupRequiredException extends AppException {
  const SetupRequiredException(super.message);
}
