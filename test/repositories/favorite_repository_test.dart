import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oshi_suke/models/work.dart';
import 'package:oshi_suke/repositories/favorite_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsFavoriteRepository', () {
    test('保存 → 読込 の往復で同じ状態が返る', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsFavoriteRepository();

      const userWork = Work(
        id: 'w_user_1',
        title: '手動追加作品',
        genre: 'アニメ',
        isFavorite: true,
      );
      await repo.save(const FavoriteState(
        favoriteWorkIds: {'w1', 'w_user_1'},
        notificationDisabledWorkIds: {'w2'},
        removedWorkIds: {'w3'},
        userWorks: [userWork],
      ));
      final loaded = await repo.load();

      expect(loaded, isNotNull);
      expect(loaded!.favoriteWorkIds, {'w1', 'w_user_1'});
      expect(loaded.notificationDisabledWorkIds, {'w2'});
      expect(loaded.removedWorkIds, {'w3'});
      expect(loaded.userWorks, hasLength(1));
      expect(loaded.userWorks.first.id, 'w_user_1');
      expect(loaded.userWorks.first.title, '手動追加作品');
      expect(loaded.userWorks.first.genre, 'アニメ');
    });

    test('未保存 (初回起動) は null を返す', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsFavoriteRepository();

      expect(await repo.load(), isNull);
    });

    test('壊れたJSONは null を返す (クラッシュしない)', () async {
      SharedPreferences.setMockInitialValues({
        'oshi_suke.favorites': 'not a json',
      });
      final repo = SharedPrefsFavoriteRepository();

      expect(await repo.load(), isNull);
    });

    test('未知の schemaVersion は null を返す', () async {
      SharedPreferences.setMockInitialValues({
        'oshi_suke.favorites': jsonEncode({
          'schemaVersion': 999,
          'favoriteWorkIds': ['w1'],
        }),
      });
      final repo = SharedPrefsFavoriteRepository();

      expect(await repo.load(), isNull);
    });
  });
}
