import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oshi_suke/repositories/bookmark_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsBookmarkRepository', () {
    test('保存 → 読込 の往復で同じIDが返る', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsBookmarkRepository();

      await repo.save({'e1', 'e2'});
      final loaded = await repo.load();

      expect(loaded, {'e1', 'e2'});
    });

    test('未保存 (初回起動) は null を返す', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsBookmarkRepository();

      expect(await repo.load(), isNull);
    });

    test('空集合を保存した場合は null ではなく空集合が返る', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsBookmarkRepository();

      await repo.save({});
      final loaded = await repo.load();

      expect(loaded, isNotNull);
      expect(loaded, isEmpty);
    });

    test('壊れたJSONは null を返す (クラッシュしない)', () async {
      SharedPreferences.setMockInitialValues({
        'oshi_suke.bookmarks': '{broken json',
      });
      final repo = SharedPrefsBookmarkRepository();

      expect(await repo.load(), isNull);
    });

    test('未知の schemaVersion は null を返す', () async {
      SharedPreferences.setMockInitialValues({
        'oshi_suke.bookmarks': jsonEncode({
          'schemaVersion': 999,
          'bookmarkedEventIds': ['e1'],
        }),
      });
      final repo = SharedPrefsBookmarkRepository();

      expect(await repo.load(), isNull);
    });
  });
}
