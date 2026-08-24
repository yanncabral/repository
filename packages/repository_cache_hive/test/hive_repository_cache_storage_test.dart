import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:repository_cache_hive/repository_cache_hive.dart';
import 'package:test/test.dart';

void main() {
  late Box<String> box;
  late HiveRepositoryCacheStorage storage;

  setUp(() {
    box = _MockBox();
    storage = HiveRepositoryCacheStorage(box: box);

    when(() => box.get(any<Object>())).thenReturn(null);
    when(() => box.put(any<Object>(), any<String>())).thenAnswer((_) async {});
    when(() => box.delete(any<Object>())).thenAnswer((_) async {});
    when(box.clear).thenAnswer((_) async => 0);
  });

  test('delete makes a previously written value unreadable', () async {
    await storage.write(key: 'session', value: 'authenticated');

    await storage.delete(key: 'session');

    expect(await storage.read(key: 'session'), isNull);
  });

  test('clear makes all previously written values unreadable', () async {
    await storage.write(key: 'session', value: 'authenticated');
    await storage.write(key: 'profile', value: 'Yann');

    await storage.clear();

    expect(await storage.read(key: 'session'), isNull);
    expect(await storage.read(key: 'profile'), isNull);
  });
}

final class _MockBox extends Mock implements Box<String> {}
