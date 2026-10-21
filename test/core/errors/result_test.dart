import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/core/errors/failure.dart';
import 'package:messenger/core/errors/result.dart';

void main() {
  group('Result monad tests', () {
    test('Success returns data and isSuccess is true', () {
      final Result<Failure, String> result = Result.success('test_data');

      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.dataOrNull, 'test_data');
      expect(result.failureOrNull, isNull);

      final mapped = result.when(
        success: (data) => 'Data: $data',
        error: (failure) => 'Error: ${failure.message}',
      );
      expect(mapped, 'Data: test_data');
    });

    test('Error returns failure and isError is true', () {
      const failure = ServerFailure(message: 'Internal server error');
      final Result<Failure, String> result = Result.error(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isError, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, failure);

      final mapped = result.when(
        success: (data) => 'Data: $data',
        error: (f) => 'Error: ${f.message}',
      );
      expect(mapped, 'Error: Internal server error');
    });
  });
}
