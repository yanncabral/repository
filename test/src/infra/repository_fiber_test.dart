import 'dart:async';

import 'package:repository/src/infra/repository_fiber.dart';
import 'package:test/test.dart';

void main() {
  group('RepositoryFiber', () {
    test('should run async function and return its result', () async {
      final fiber = RepositoryFiber<int>();
      final result = await fiber.run(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return 42;
      });
      expect(result, equals(42));
    });

    test('should wait for running async function to complete', () async {
      final fiber = RepositoryFiber<int>();
      final completer1 = Completer<int>();
      var secondFunctionRan = false;
      final future1 = fiber.run(() => completer1.future);
      final future2 = fiber.run(() async {
        secondFunctionRan = true;
        return 2;
      });
      expect(fiber.isBusy, isTrue);
      completer1.complete(1);
      expect(await future1, equals(1));
      expect(await future2, equals(1));
      expect(secondFunctionRan, isFalse);
      expect(fiber.isBusy, isFalse);
    });

    test('should accept a new function after completing', () async {
      final fiber = RepositoryFiber<int>();
      final completer1 = Completer<int>();
      final future1 = fiber.run(() => completer1.future);

      expect(fiber.isBusy, isTrue);
      completer1.complete(1);
      expect(await future1, equals(1));
      expect(fiber.isBusy, isFalse);

      final future3 = fiber.run(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return 3;
      });
      expect(fiber.isBusy, isTrue);
      final result = await future3;
      expect(result, equals(3));
      expect(fiber.isBusy, isFalse);
    });
  });
}
