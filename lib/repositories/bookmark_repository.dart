import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ブックマーク済みイベントIDの永続化 (端末への保存) を担う抽象層。
///
/// UI / Provider はこのインターフェースにのみ依存する。
/// 将来 Firestore 等に移行するときは実装クラスを差し替えるだけでよい。
///
/// **優先順位の方針 (重要)**:
///   配信JSON (events.json) の `isBookmarked` とローカル保存が食い違う場合、
///   必ず **ローカル側を優先** する。ブックマークはユーザーの操作結果であり、
///   全ユーザー共通の配信データが上書きしてよいものではないため。
///   (適用箇所: EventsNotifier._load)
abstract class BookmarkRepository {
  /// 保存済みのブックマークIDを読み込む。
  ///
  /// まだ一度も保存されていない (= 初回起動)、保存データが壊れている、
  /// または未知の schemaVersion の場合は null を返す。
  /// 呼び出し側は null のとき配信データの初期値を種として保存する。
  Future<Set<String>?> load();

  /// 現在のブックマークID一覧を保存する (全置き換え)。
  Future<void> save(Set<String> bookmarkedEventIds);
}

/// shared_preferences (端末内のキーバリュー保存) 実装。
class SharedPrefsBookmarkRepository implements BookmarkRepository {
  SharedPrefsBookmarkRepository({Future<SharedPreferences>? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance();

  /// 保存形式の版数。形式を変えるときは +1 し、load() に移行処理を足す。
  static const schemaVersion = 1;

  static const _key = 'oshi_suke.bookmarks';

  final Future<SharedPreferences> _prefs;

  @override
  Future<Set<String>?> load() async {
    try {
      final raw = (await _prefs).getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['schemaVersion'] != schemaVersion) return null;
      return (json['bookmarkedEventIds'] as List?)
              ?.whereType<String>()
              .toSet() ??
          <String>{};
    } catch (e) {
      debugPrint('[BookmarkRepository] load failed: $e');
      return null;
    }
  }

  @override
  Future<void> save(Set<String> bookmarkedEventIds) async {
    try {
      final raw = jsonEncode({
        'schemaVersion': schemaVersion,
        'bookmarkedEventIds': bookmarkedEventIds.toList(),
      });
      await (await _prefs).setString(_key, raw);
    } catch (e) {
      debugPrint('[BookmarkRepository] save failed: $e');
    }
  }
}
