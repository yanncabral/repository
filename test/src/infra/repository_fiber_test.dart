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
      final completer2 = Completer<int>();
      final future1 = fiber.run(() => completer1.future);
      final future2 = fiber.run(() => completer2.future);
      expect(fiber.isBusy, isTrue);
      completer1.complete(1);
      await future1;
      expect(fiber.isBusy, isTrue);
      completer2.complete(2);
      final result = await future2;
      expect(result, equals(2));
      expect(fiber.isBusy, isFalse);
    });

    test("shouldn't run multiple async functions sequentially", () async {
      final fiber = RepositoryFiber<int>();
      final completer1 = Completer<int>();
      final completer2 = Completer<int>();
      final future1 = fiber.run(() => completer1.future);
      final future2 = fiber.run(() => completer2.future);

      expect(fiber.isBusy, isTrue);
      completer1.complete(1);
      final response1 = await future1;
      expect(fiber.isBusy, isFalse);
      expect(future1, future2);
      final response2 = await future2;
      completer2.complete(2);
      await future2;
      expect(fiber.isBusy, isFalse);
      expect(response1, response2);
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
