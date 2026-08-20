import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/remote_data_config.dart';
import '../models/event_status.dart';
import '../models/oshi_event.dart';
import '../repositories/bookmark_repository.dart';
import '../repositories/event_repository.dart';
import '../repositories/json_asset_event_repository.dart';
import '../repositories/remote_json_event_repository.dart';
import '../repositories/settings_repository.dart';
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

/// ブックマークの永続化リポジトリ。
/// 将来 Firestore に差し替える場合はここを書き換えるだけでよい。
final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return SharedPrefsBookmarkRepository();
});

/// 通知設定の永続化リポジトリ。
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SharedPrefsSettingsRepository();
});

class EventsNotifier extends StateNotifier<List<OshiEvent>> {
  EventsNotifier(this._repository, this._bookmarkRepository)
      : super(const []) {
    _load();
  }

  final EventRepository _repository;
  final BookmarkRepository _bookmarkRepository;

  Future<void> _load() async {
    final events = await _repository.fetchAll();
    final saved = await _bookmarkRepository.load();
    if (saved == null) {
      // 初回起動: 配信JSONの isBookmarked を種としてローカルに保存する。
      // 以後はローカル保存が唯一の正となる。
      state = events;
      await _bookmarkRepository.save({
        for (final e in events)
          if (e.isBookmarked) e.id,
      });
    } else {
      // ローカル優先: 配信JSON側の isBookmarked とローカル保存が食い違う
      // 場合、必ずローカル (ユーザー操作の結果) を採用する。配信データが
      // ユーザーの「外した」操作を復活させてはならないため。
      state = [
        for (final e in events) e.copyWith(isBookmarked: saved.contains(e.id)),
      ];
    }
  }

  void toggleBookmark(String eventId) {
    state = [
      for (final e in state)
        if (e.id == eventId) e.copyWith(isBookmarked: !e.isBookmarked) else e,
    ];
    // ignore: discarded_futures
    _bookmarkRepository.save({
      for (final e in state)
        if (e.isBookmarked) e.id,
    });
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
  return EventsNotifier(
    ref.watch(eventRepositoryProvider),
    ref.watch(bookmarkRepositoryProvider),
  );
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
  NotificationSettingsNotifier(this._repository)
      : super(const NotificationSettings()) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    final saved = await _repository.load();
    if (saved != null) state = saved;
  }

  /// 状態を更新し、即座に永続化する。
  void _update(NotificationSettings next) {
    state = next;
    // ignore: discarded_futures
    _repository.save(next);
  }

  void setNotifyBeforeReservationStart(bool v) =>
      _update(state.copyWith(notifyBeforeReservationStart: v));
  void setNotifyBeforeReservationEnd(bool v) =>
      _update(state.copyWith(notifyBeforeReservationEnd: v));
  void setNotifyBeforeEventStart(bool v) =>
      _update(state.copyWith(notifyBeforeEventStart: v));
  void setNotifyOnDay(bool v) => _update(state.copyWith(notifyOnDay: v));
  void setNotifyOneDayBefore(bool v) =>
      _update(state.copyWith(notifyOneDayBefore: v));
  void setNotifyThreeDaysBefore(bool v) =>
      _update(state.copyWith(notifyThreeDaysBefore: v));
}

final notificationSettingsProvider = StateNotifierProvider<
    NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier(ref.watch(settingsRepositoryProvider));
});
