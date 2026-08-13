import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/remote_data_config.dart';
import '../models/event_status.dart';
import '../models/oshi_event.dart';
import '../repositories/event_repository.dart';
import '../repositories/json_asset_event_repository.dart';
import '../repositories/remote_json_event_repository.dart';
import '../services/event_status_service.dart';
import '../services/notification_setting_service.dart';

/// イベントリポジトリの提供。
///
/// 取得チェーン:
///   1. [RemoteDataConfig.eventsJsonUrl] が設定されていれば外部 URL から取得
///   2. 失敗 (タイムアウト / 非200 / JSON 不正) → assets/data/events.json
///   3. それも失敗 → buildMockEvents()
///
/// 将来 Firestore / API / スクレイピングに差し替える場合はここを書き換える。
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final asset = JsonAssetEventRepository();
  final urlStr = RemoteDataConfig.eventsJsonUrl;
  if (urlStr == null || urlStr.isEmpty) {
    return asset;
  }
  final repo = RemoteJsonEventRepository(
    url: Uri.parse(urlStr),
    fallback: asset,
  );
  ref.onDispose(repo.dispose);
  return repo;
});

final eventStatusServiceProvider = Provider<EventStatusService>((ref) {
  return const EventStatusService();
});

class EventsNotifier extends StateNotifier<List<OshiEvent>> {
  EventsNotifier(this._repository) : super(const []) {
    _load();
  }

  final EventRepository _repository;

  Future<void> _load() async {
    state = await _repository.fetchAll();
  }

  void toggleBookmark(String eventId) {
    state = [
      for (final e in state)
        if (e.id == eventId) e.copyWith(isBookmarked: !e.isBookmarked) else e,
    ];
  }

  OshiEvent? findById(String eventId) {
    for (final e in state) {
      if (e.id == eventId) return e;
    }
    return null;
  }

  List<OshiEvent> byWork(String workId) {
    return state.where((e) => e.workId == workId).toList();
  }
}

final eventsProvider =
    StateNotifierProvider<EventsNotifier, List<OshiEvent>>((ref) {
  return EventsNotifier(ref.watch(eventRepositoryProvider));
});

/// 締切間近イベント
final deadlineSoonEventsProvider = Provider<List<OshiEvent>>((ref) {
  final events = ref.watch(eventsProvider);
  final svc = ref.watch(eventStatusServiceProvider);
  return svc.deadlineSoon(events)
    ..sort((a, b) {
      final ad = a.reservationEndDate ?? a.endDate ?? a.releaseDate;
      final bd = b.reservationEndDate ?? b.endDate ?? b.releaseDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
});

/// 開催中イベント
final activeEventsProvider = Provider<List<OshiEvent>>((ref) {
  final events = ref.watch(eventsProvider);
  final svc = ref.watch(eventStatusServiceProvider);
  return svc.active(events);
});

/// 近日開始イベント
final upcomingEventsProvider = Provider<List<OshiEvent>>((ref) {
  final events = ref.watch(eventsProvider);
  final svc = ref.watch(eventStatusServiceProvider);
  return svc.upcoming(events)
    ..sort((a, b) {
      final ad = a.startDate ?? a.releaseDate;
      final bd = b.startDate ?? b.releaseDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
});

/// 今日の新着
final newlyAddedEventsProvider = Provider<List<OshiEvent>>((ref) {
  final events = ref.watch(eventsProvider);
  final svc = ref.watch(eventStatusServiceProvider);
  return svc.newlyAdded(events);
});

/// ブックマーク
final bookmarkedEventsProvider = Provider<List<OshiEvent>>((ref) {
  return ref.watch(eventsProvider).where((e) => e.isBookmarked).toList();
});

/// イベント1件のステータス
final eventStatusProvider =
    Provider.family<EventStatus, OshiEvent>((ref, event) {
  return ref.watch(eventStatusServiceProvider).statusOf(event);
});

/// 通知設定 (ローカル状態 + 端末への schedule 反映)。
///
/// 値が変わるたびに [notificationSchedulerProvider] が
/// 再スケジューリングするため、ここでは状態保持に専念する。
class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(const NotificationSettings());

  void setNotifyBeforeReservationStart(bool v) =>
      state = state.copyWith(notifyBeforeReservationStart: v);
  void setNotifyBeforeReservationEnd(bool v) =>
      state = state.copyWith(notifyBeforeReservationEnd: v);
  void setNotifyBeforeEventStart(bool v) =>
      state = state.copyWith(notifyBeforeEventStart: v);
  void setNotifyOnDay(bool v) => state = state.copyWith(notifyOnDay: v);
  void setNotifyOneDayBefore(bool v) =>
      state = state.copyWith(notifyOneDayBefore: v);
  void setNotifyThreeDaysBefore(bool v) =>
      state = state.copyWith(notifyThreeDaysBefore: v);
}

final notificationSettingsProvider = StateNotifierProvider<
    NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier();
});
