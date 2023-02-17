import 'package:repository/repository.dart';
import 'package:test/test.dart';

void main() {
  group('Repository', () {
    test('can be instantiated', () {
      expect(const Repository(), isNotNull);
    });
  });
}
