import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_setting_service.dart';

/// 通知設定の永続化を担う抽象層。
///
/// 将来 Firestore 等に移行するときは実装クラスを差し替えるだけでよい。
abstract class SettingsRepository {
  /// 保存済みの通知設定を読み込む。
  ///
  /// 未保存 (初回起動)、壊れたデータ、未知の schemaVersion では null。
  /// 呼び出し側は null のときデフォルト設定のまま動く。
  Future<NotificationSettings?> load();

  /// 現在の通知設定を保存する。
  Future<void> save(NotificationSettings settings);
}

/// shared_preferences 実装。
class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository({Future<SharedPreferences>? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance();

  /// 保存形式の版数。形式を変えるときは +1 し、load() に移行処理を足す。
  static const schemaVersion = 1;

  static const _key = 'oshi_suke.notification_settings';

  final Future<SharedPreferences> _prefs;

  @override
  Future<NotificationSettings?> load() async {
    try {
      final raw = (await _prefs).getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['schemaVersion'] != schemaVersion) return null;

      bool flag(String key) => json[key] as bool? ?? true;

      return NotificationSettings(
        notifyBeforeReservationStart: flag('notifyBeforeReservationStart'),
        notifyBeforeReservationEnd: flag('notifyBeforeReservationEnd'),
        notifyBeforeEventStart: flag('notifyBeforeEventStart'),
        notifyOnDay: flag('notifyOnDay'),
        notifyOneDayBefore: flag('notifyOneDayBefore'),
        notifyThreeDaysBefore: flag('notifyThreeDaysBefore'),
      );
    } catch (e) {
      debugPrint('[SettingsRepository] load failed: $e');
      return null;
    }
  }

  @override
  Future<void> save(NotificationSettings settings) async {
    try {
      final raw = jsonEncode({
        'schemaVersion': schemaVersion,
        'notifyBeforeReservationStart': settings.notifyBeforeReservationStart,
        'notifyBeforeReservationEnd': settings.notifyBeforeReservationEnd,
        'notifyBeforeEventStart': settings.notifyBeforeEventStart,
        'notifyOnDay': settings.notifyOnDay,
        'notifyOneDayBefore': settings.notifyOneDayBefore,
        'notifyThreeDaysBefore': settings.notifyThreeDaysBefore,
      });
      await (await _prefs).setString(_key, raw);
    } catch (e) {
      debugPrint('[SettingsRepository] save failed: $e');
    }
  }
}
