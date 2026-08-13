import 'package:flutter/foundation.dart';

import '../models/oshi_event.dart';
import '../models/work.dart';
import 'notification_setting_service.dart';

/// 1件のスケジュール対象通知を表す純粋データ。
///
/// プランナーは [NotificationService] とは独立してテスト可能。
/// プラットフォームAPIに依存しないので、ロジックの変更だけならテストで完結する。
@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.eventId,
    required this.workId,
    required this.kind,
    required this.leadTime,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });

  /// flutter_local_notifications に渡す int ID (31bit 範囲)。
  final int id;
  final String eventId;
  final String workId;
  final NotificationTriggerKind kind;
  final NotificationLeadTime leadTime;
  final DateTime scheduledAt;
  final String title;
  final String body;

  @override
  String toString() =>
      'PlannedNotification(id=$id, $eventId, ${kind.name}, ${leadTime.name}, '
      '$scheduledAt, "$title")';
}

/// 通知 ID を eventId / kind / leadTime から決定的に算出する。
///
/// 同一の (eventId, kind, leadTime) に対して常に同じ int を返すので、
/// 「再スケジュール時に古い通知を上書きする」運用が実現できる。
int computeNotificationId(
    String eventId, NotificationTriggerKind kind, NotificationLeadTime leadTime) {
  // 31bit に収めて Android NotificationManager と互換にする。
  return '$eventId|${kind.name}|${leadTime.name}'.hashCode & 0x7FFFFFFF;
}

/// 通知の発火時刻 (= 対象日 [date] の `--leadDays` 日前の朝 9:00)。
///
/// 9 時固定にしている理由:
///  - 早朝すぎると ON/OFF 通知の体験が悪い
///  - 出勤前後の現実的な「気付くタイミング」
DateTime computeScheduledAt(DateTime date, int leadDays,
    {int hourOfDay = 9, int minuteOfDay = 0}) {
  final atDate = DateTime(date.year, date.month, date.day, hourOfDay, minuteOfDay);
  return atDate.subtract(Duration(days: leadDays));
}

/// 開発デバッグ用フラグ。
///
/// **本番では必ず `false` に戻すこと。**
///
/// `true` にすると [NotificationPlanner.plan] は **「1件だけ」** の通知を
/// 「現在時刻 + 1分」に予約して返す。実機で「ブックマークしたら通知が来る」
/// 経路がちゃんと動いているかを 1分後に1件で確認できる。
///
/// 選定ロジック (`_planDebugSingle`):
///   1. ブックマーク済みイベントを最優先、無ければお気に入り作品の関連イベント
///   2. トリガー種類は `予約締切` → `開催開始` → `予約開始` の順で最初に該当した1つ
///   3. リードタイムは常に `当日` 扱い (1分後発火)
///
/// 通知タイトル:  `[テスト通知] ○○イベント`
/// 通知ボディ:   `デバッグ通知です(1分後発火) / 作品名 / トリガー種類`
///
/// - 通知対象判定 (ブックマーク / お気に入り作品) は通常通り効く
/// - 設定でトリガー種類 OFF にしている場合はその種類は使わない
/// - 「対象日が過去かどうか」のフィルタはスキップされる (デバッグ用に常に未来扱い)
const bool kDebugImmediateNotification = false;

/// (events, bookmarks, favorites, settings, now) から
/// **その時点で実際にスケジュールすべき通知一覧** を組み立てる純粋関数。
///
/// - 過去の発火時刻はスキップ
/// - 設定で無効化されているトリガー / リードタイムはスキップ
/// - 通知対象 = `bookmarkedEventIds` か、`favoriteWorkIds` に含まれる作品の関連イベント
/// - [debugImmediateNotification] が `true` の場合は発火時刻を「現在 + 1分」に上書きする
///   (実機での通知到達確認用)
class NotificationPlanner {
  const NotificationPlanner({
    this.debugImmediateNotification = kDebugImmediateNotification,
  });

  /// true のとき、すべての通知を「現在 + 1分」にスケジュールする。
  /// テスト時はコンストラクタで明示的に切り替えできる。
  final bool debugImmediateNotification;

  List<PlannedNotification> plan({
    required List<OshiEvent> events,
    required Iterable<Work> works,
    required Set<String> bookmarkedEventIds,
    required NotificationSettings settings,
    DateTime? now,
  }) {
    if (settings.isCompletelyDisabled) return const [];

    final favoriteWorkIds = <String>{
      for (final w in works)
        if (w.isFavorite) w.id,
    };
    final triggers = settings.enabledTriggers;
    final leadTimes = settings.enabledLeadTimes;
    final clock = now ?? DateTime.now();

    // ─── デバッグモード: 通知の到達確認用に「1件だけ」発火させる ───
    // 9 通知 × 全イベントが同時発火すると分かりにくいので、優先度の高い
    // 1 件だけ「現在 + 1分」で予約する。
    if (debugImmediateNotification) {
      return _planDebugSingle(
        events: events,
        bookmarkedEventIds: bookmarkedEventIds,
        favoriteWorkIds: favoriteWorkIds,
        triggers: triggers,
        now: clock,
      );
    }

    // ─── 通常モード ───
    final plans = <PlannedNotification>[];

    for (final e in events) {
      final isTarget = bookmarkedEventIds.contains(e.id) ||
          favoriteWorkIds.contains(e.workId);
      if (!isTarget) continue;

      for (final kind in triggers) {
        final date = _dateFor(e, kind);
        if (date == null) continue;

        for (final leadTime in leadTimes) {
          final scheduledAt = computeScheduledAt(date, leadTime.days);
          if (!scheduledAt.isAfter(clock)) {
            // 既に過ぎた発火時刻はスキップ (二重通知や即時発火を防ぐ)
            continue;
          }

          plans.add(PlannedNotification(
            id: computeNotificationId(e.id, kind, leadTime),
            eventId: e.id,
            workId: e.workId,
            kind: kind,
            leadTime: leadTime,
            scheduledAt: scheduledAt,
            title: _titleFor(e, kind, leadTime),
            body: _bodyFor(e, kind),
          ));
        }
      }
    }

    plans.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return plans;
  }

  /// デバッグモード: 1件だけ通知を返す。
  ///
  /// 選定優先度:
  ///   1. ブックマーク済みイベントを優先 (お気に入り作品より上)
  ///   2. トリガー種類は `reservationEnd` > `eventStart` > `reservationStart` の順
  ///   3. リードタイムは常に `onDay` 固定
  ///
  /// 設定 (どのトリガーを許可するか) は引き続き尊重するが、
  /// リードタイム ON/OFF はデバッグ時には参照しない (常に onDay 扱い)。
  List<PlannedNotification> _planDebugSingle({
    required List<OshiEvent> events,
    required Set<String> bookmarkedEventIds,
    required Set<String> favoriteWorkIds,
    required Set<NotificationTriggerKind> triggers,
    required DateTime now,
  }) {
    if (triggers.isEmpty) return const [];

    // 優先順: 「予約締切」が最も実用的なので最優先
    const kindPriority = <NotificationTriggerKind>[
      NotificationTriggerKind.reservationEnd,
      NotificationTriggerKind.eventStart,
      NotificationTriggerKind.reservationStart,
    ];

    // 対象集合 = ブックマーク済み + お気に入り作品の関連イベント
    // ブックマーク済みを先に並べてループ (優先度付け)
    final bookmarked = events.where((e) => bookmarkedEventIds.contains(e.id));
    final favorite = events.where((e) =>
        !bookmarkedEventIds.contains(e.id) &&
        favoriteWorkIds.contains(e.workId));
    final ordered = [...bookmarked, ...favorite];

    final scheduledAt = now.add(const Duration(minutes: 1));

    for (final e in ordered) {
      for (final kind in kindPriority) {
        if (!triggers.contains(kind)) continue;
        if (_dateFor(e, kind) == null) continue;

        return [
          PlannedNotification(
            id: computeNotificationId(
                e.id, kind, NotificationLeadTime.onDay),
            eventId: e.id,
            workId: e.workId,
            kind: kind,
            leadTime: NotificationLeadTime.onDay,
            scheduledAt: scheduledAt,
            title: '[テスト通知] ${e.title}',
            body: 'デバッグ通知です(1分後発火) / ${e.workTitle} / ${_kindLabel(kind)}',
          ),
        ];
      }
    }

    return const [];
  }

  String _kindLabel(NotificationTriggerKind kind) {
    switch (kind) {
      case NotificationTriggerKind.reservationStart:
        return '予約開始';
      case NotificationTriggerKind.reservationEnd:
        return '予約締切';
      case NotificationTriggerKind.eventStart:
        return '開催開始';
    }
  }

  DateTime? _dateFor(OshiEvent e, NotificationTriggerKind kind) {
    switch (kind) {
      case NotificationTriggerKind.reservationStart:
        return e.reservationStartDate;
      case NotificationTriggerKind.reservationEnd:
        return e.reservationEndDate;
      case NotificationTriggerKind.eventStart:
        // 開催日が無いグッズなどは発売日にフォールバック
        return e.startDate ?? e.releaseDate;
    }
  }

  String _titleFor(OshiEvent e, NotificationTriggerKind kind,
      NotificationLeadTime leadTime) {
    final lead = leadTime.label; // 当日 / 1日前 / 3日前
    switch (kind) {
      case NotificationTriggerKind.reservationStart:
        return leadTime == NotificationLeadTime.onDay
            ? '本日 予約開始: ${e.title}'
            : '$lead 予約開始: ${e.title}';
      case NotificationTriggerKind.reservationEnd:
        return leadTime == NotificationLeadTime.onDay
            ? '本日 予約締切: ${e.title}'
            : '$lead 予約締切: ${e.title}';
      case NotificationTriggerKind.eventStart:
        return leadTime == NotificationLeadTime.onDay
            ? '本日 開催開始: ${e.title}'
            : '$lead 開催開始: ${e.title}';
    }
  }

  String _bodyFor(OshiEvent e, NotificationTriggerKind kind) {
    final parts = <String>[
      e.workTitle,
      if (e.location != null) e.location!,
      if (e.shopName != null) e.shopName!,
    ];
    return parts.join(' / ');
  }
}
