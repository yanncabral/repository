import 'package:repository/src/infra/repository_fiber.dart';
import 'package:test/test.dart';

void main() {
  group('RepositoryFiber', () {
    test('run returns the correct result', () async {
      final fiber = RepositoryFiber<int>();
      final result = await fiber.run(() async => 1);
      expect(result, equals(1));
    });

    test(
        'run returns the same future if called again before the previous '
        'async function has finished', () async {
      final fiber = RepositoryFiber<int>();
      final future1 = fiber.run(() async {
        return Future<int>.delayed(const Duration(seconds: 2), () => 1);
      });

      final value2 = await fiber.run(() async => 2);

      expect(await future1, equals(1));
      expect(value2, equals(1));
    });

    test(
        'run returns the result of the new async function if called after '
        'the previous async function has finished', () async {
      final fiber = RepositoryFiber<int>();
      await fiber.run(() async => 1);
      final result = await fiber.run(() async => 2);
      expect(result, equals(2));
    });

    test(
        'run throws the correct error if the passed async '
        'function throws an error', () async {
      final fiber = RepositoryFiber<int>();
      try {
        await fiber.run(() async => throw Exception('Test exception'));
      } catch (e) {
        expect(e, isException);
        expect(e.toString(), equals('Exception: Test exception'));
      }
    });
  });
}
