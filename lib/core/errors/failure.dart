sealed class Failure {
  const Failure({required this.message, this.cause});
  final String message;
  final dynamic cause;

  @override
  String toString() => message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.cause});
}

final class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    this.code,
    this.statusCode,
    super.cause,
  });
  final String? code;
  final int? statusCode;
}

final class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.cause});
}

final class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.cause});
}

final class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.cause});
}
