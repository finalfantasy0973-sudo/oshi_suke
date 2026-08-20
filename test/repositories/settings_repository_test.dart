import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oshi_suke/repositories/settings_repository.dart';
import 'package:oshi_suke/services/notification_setting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsSettingsRepository', () {
    test('保存 → 読込 の往復で同じ設定が返る', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsSettingsRepository();

      const settings = NotificationSettings(
        notifyBeforeReservationStart: false,
        notifyBeforeReservationEnd: true,
        notifyBeforeEventStart: false,
        notifyOnDay: true,
        notifyOneDayBefore: false,
        notifyThreeDaysBefore: true,
      );
      await repo.save(settings);
      final loaded = await repo.load();

      expect(loaded, isNotNull);
      expect(loaded!.notifyBeforeReservationStart, false);
      expect(loaded.notifyBeforeReservationEnd, true);
      expect(loaded.notifyBeforeEventStart, false);
      expect(loaded.notifyOnDay, true);
      expect(loaded.notifyOneDayBefore, false);
      expect(loaded.notifyThreeDaysBefore, true);
    });

    test('未保存 (初回起動) は null を返す', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsSettingsRepository();

      expect(await repo.load(), isNull);
    });

    test('壊れたJSONは null を返す (クラッシュしない)', () async {
      SharedPreferences.setMockInitialValues({
        'oshi_suke.notification_settings': '[]',
      });
      final repo = SharedPrefsSettingsRepository();

      expect(await repo.load(), isNull);
    });

    test('未知の schemaVersion は null を返す', () async {
      SharedPreferences.setMockInitialValues({
        'oshi_suke.notification_settings': jsonEncode({
          'schemaVersion': 999,
          'notifyOnDay': false,
        }),
      });
      final repo = SharedPrefsSettingsRepository();

      expect(await repo.load(), isNull);
    });
  });
}
