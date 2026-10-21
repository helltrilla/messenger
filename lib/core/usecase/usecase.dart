import '../errors/failure.dart';
import '../errors/result.dart';

abstract class UseCase<T, Params> {
  Future<Result<Failure, T>> call(Params params);
}

class NoParams {
  const NoParams();
}
