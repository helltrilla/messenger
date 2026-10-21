import 'failure.dart';

sealed class Result<F extends Failure, S> {
  const Result();

  factory Result.success(S data) = Success<F, S>;
  factory Result.error(F failure) = Error<F, S>;

  bool get isSuccess => this is Success<F, S>;
  bool get isError => this is Error<F, S>;

  S? get dataOrNull => switch (this) {
    Success(data: final d) => d,
    Error() => null,
  };

  F? get failureOrNull => switch (this) {
    Success() => null,
    Error(failure: final f) => f,
  };

  R when<R>({
    required R Function(S data) success,
    required R Function(F failure) error,
  }) {
    return switch (this) {
      Success(data: final d) => success(d),
      Error(failure: final f) => error(f),
    };
  }
}

final class Success<F extends Failure, S> extends Result<F, S> {
  final S data;
  const Success(this.data);
}

final class Error<F extends Failure, S> extends Result<F, S> {
  final F failure;
  const Error(this.failure);
}
