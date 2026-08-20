import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/work.dart';

/// 作品まわりのユーザー状態のスナップショット (保存単位)。
@immutable
class FavoriteState {
  const FavoriteState({
    this.favoriteWorkIds = const {},
    this.notificationDisabledWorkIds = const {},
    this.removedWorkIds = const {},
    this.userWorks = const [],
  });

  /// お気に入りON の作品ID。
  final Set<String> favoriteWorkIds;

  /// 作品単位で通知OFF にした作品ID (デフォルトON なのでOFF だけ覚える)。
  final Set<String> notificationDisabledWorkIds;

  /// 配信カタログから削除した作品ID (再起動で復活させないため)。
  final Set<String> removedWorkIds;

  /// ユーザーが手動追加した作品 (配信データに存在しない)。
  final List<Work> userWorks;
}

/// お気に入り・作品状態の永続化を担う抽象層。
///
/// **優先順位の方針**: 配信JSON (works.json) の `isFavorite` /
/// `notificationEnabled` とローカル保存が食い違う場合、必ずローカル側を
/// 優先する ([BookmarkRepository] と同じ理由)。
abstract class FavoriteRepository {
  /// 保存済み状態を読み込む。
  ///
  /// 未保存 (初回起動)、壊れたデータ、未知の schemaVersion では null。
  Future<FavoriteState?> load();

  /// 現在の状態を保存する (全置き換え)。
  Future<void> save(FavoriteState state);
}

/// shared_preferences 実装。
class SharedPrefsFavoriteRepository implements FavoriteRepository {
  SharedPrefsFavoriteRepository({Future<SharedPreferences>? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance();

  /// 保存形式の版数。形式を変えるときは +1 し、load() に移行処理を足す。
  static const schemaVersion = 1;

  static const _key = 'oshi_suke.favorites';

  final Future<SharedPreferences> _prefs;

  @override
  Future<FavoriteState?> load() async {
    try {
      final raw = (await _prefs).getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['schemaVersion'] != schemaVersion) return null;

      Set<String> ids(String key) =>
          (json[key] as List?)?.whereType<String>().toSet() ?? <String>{};

      return FavoriteState(
        favoriteWorkIds: ids('favoriteWorkIds'),
        notificationDisabledWorkIds: ids('notificationDisabledWorkIds'),
        removedWorkIds: ids('removedWorkIds'),
        userWorks: (json['userWorks'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Work.fromJson)
                .toList() ??
            const [],
      );
    } catch (e) {
      debugPrint('[FavoriteRepository] load failed: $e');
      return null;
    }
  }

  @override
  Future<void> save(FavoriteState state) async {
    try {
      final raw = jsonEncode({
        'schemaVersion': schemaVersion,
        'favoriteWorkIds': state.favoriteWorkIds.toList(),
        'notificationDisabledWorkIds':
            state.notificationDisabledWorkIds.toList(),
        'removedWorkIds': state.removedWorkIds.toList(),
        'userWorks': [for (final w in state.userWorks) w.toJson()],
      });
      await (await _prefs).setString(_key, raw);
    } catch (e) {
      debugPrint('[FavoriteRepository] save failed: $e');
    }
  }
}
