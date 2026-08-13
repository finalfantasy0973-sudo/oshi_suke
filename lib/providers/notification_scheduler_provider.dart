import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_planner.dart';
import '../services/notification_service.dart';
import 'event_provider.dart';
import 'work_provider.dart';

/// アプリ全体で 1 つだけ持つ [NotificationService]。
///
/// init() は main.dart で呼ぶため、ここでは構築だけ行う。
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.cancelAll);
  return service;
});

/// 純粋プランナー (テストしやすいよう Provider 経由で取得)。
final notificationPlannerProvider = Provider<NotificationPlanner>((ref) {
  return const NotificationPlanner();
});

/// その時点で **スケジュールすべき通知** の一覧を導出する。
///
/// イベント / お気に入り / ブックマーク / 通知設定 のいずれかが変わると
/// 自動で再計算される。
final plannedNotificationsProvider =
    Provider<List<PlannedNotification>>((ref) {
  final events = ref.watch(eventsProvider);
  final works = ref.watch(worksProvider);
  final settings = ref.watch(notificationSettingsProvider);
  final planner = ref.watch(notificationPlannerProvider);

  final bookmarkedIds = <String>{
    for (final e in events)
      if (e.isBookmarked) e.id,
  };

  return planner.plan(
    events: events,
    works: works,
    bookmarkedEventIds: bookmarkedIds,
    settings: settings,
  );
});

/// プラン変更を端末側スケジュールに反映する副作用 Provider。
///
/// [plannedNotificationsProvider] が変わるたびに [NotificationService.applyPlan]
/// を呼ぶ。最初の起動時にも 1 回呼ばれて初期スケジュールが入る。
///
/// `keepAlive: true` でアプリ生存中ずっと購読を維持する。
final notificationSchedulerProvider = Provider<void>((ref) {
  ref.keepAlive();

  final service = ref.watch(notificationServiceProvider);

  ref.listen<List<PlannedNotification>>(
    plannedNotificationsProvider,
    (prev, next) {
      // 初回も含めて毎回適用
      // ignore: discarded_futures
      service.applyPlan(next);
    },
    fireImmediately: true,
  );
}, name: 'notificationSchedulerProvider');
