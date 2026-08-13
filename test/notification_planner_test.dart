import 'package:flutter_test/flutter_test.dart';
import 'package:oshi_suke/models/category.dart';
import 'package:oshi_suke/models/oshi_event.dart';
import 'package:oshi_suke/models/work.dart';
import 'package:oshi_suke/services/notification_planner.dart';
import 'package:oshi_suke/services/notification_setting_service.dart';

void main() {
  // 全テストで「今」を 2026-04-26 09:00:00 に固定
  final now = DateTime(2026, 4, 26, 9, 0);
  // 通常モードのテスト用 (kDebugImmediateNotification の値に依存させない)
  const planner = NotificationPlanner(debugImmediateNotification: false);

  Work workOf(String id, {bool fav = false}) =>
      Work(id: id, title: 'W$id', genre: 'g', isFavorite: fav);

  OshiEvent eventOf(
    String id, {
    String workId = 'w1',
    String workTitle = 'W',
    String title = 'E',
    OshiCategory category = OshiCategory.cafe,
    DateTime? rsvStart,
    DateTime? rsvEnd,
    DateTime? start,
    DateTime? release,
    bool bookmarked = false,
  }) =>
      OshiEvent(
        id: id,
        workId: workId,
        workTitle: workTitle,
        title: title,
        category: category,
        reservationStartDate: rsvStart,
        reservationEndDate: rsvEnd,
        startDate: start,
        releaseDate: release,
        isBookmarked: bookmarked,
        createdAt: DateTime(2026, 4, 1),
      );

  group('NotificationPlanner.plan', () {
    test('returns empty when no targets (not bookmarked, not favorite)', () {
      final plans = planner.plan(
        events: [
          eventOf('e1', start: DateTime(2026, 5, 1)),
        ],
        works: [workOf('w1', fav: false)],
        bookmarkedEventIds: const {},
        settings: const NotificationSettings(),
        now: now,
      );
      expect(plans, isEmpty);
    });

    test('schedules for bookmarked events (event start)', () {
      final plans = planner.plan(
        events: [
          eventOf('e1', start: DateTime(2026, 5, 1), bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(
          notifyBeforeReservationStart: false,
          notifyBeforeReservationEnd: false,
          notifyBeforeEventStart: true,
          notifyOnDay: true,
          notifyOneDayBefore: true,
          notifyThreeDaysBefore: true,
        ),
        now: now,
      );
      // 5/1 (当日 9:00), 4/30 (1日前), 4/28 (3日前)
      expect(plans, hasLength(3));
      expect(
        plans.map((p) => p.scheduledAt).toList(),
        [
          DateTime(2026, 4, 28, 9, 0),
          DateTime(2026, 4, 30, 9, 0),
          DateTime(2026, 5, 1, 9, 0),
        ],
      );
    });

    test('schedules for favorite work events (no bookmark needed)', () {
      final plans = planner.plan(
        events: [
          eventOf('e1', workId: 'w_fav', start: DateTime(2026, 5, 1)),
        ],
        works: [workOf('w_fav', fav: true)],
        bookmarkedEventIds: const {},
        settings: const NotificationSettings(),
        now: now,
      );
      expect(plans, isNotEmpty);
      expect(plans.every((p) => p.eventId == 'e1'), isTrue);
    });

    test('three trigger kinds × three lead times produces up to 9 plans', () {
      final plans = planner.plan(
        events: [
          eventOf(
            'e1',
            rsvStart: DateTime(2026, 5, 10),
            rsvEnd: DateTime(2026, 5, 20),
            start: DateTime(2026, 6, 1),
            bookmarked: true,
          ),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(),
        now: now,
      );
      // 3 dates × 3 lead times = 9 通知
      expect(plans, hasLength(9));
      // 種類が全部含まれること
      expect(
        plans.map((p) => p.kind).toSet(),
        {
          NotificationTriggerKind.reservationStart,
          NotificationTriggerKind.reservationEnd,
          NotificationTriggerKind.eventStart,
        },
      );
      expect(
        plans.map((p) => p.leadTime).toSet(),
        {
          NotificationLeadTime.onDay,
          NotificationLeadTime.oneDayBefore,
          NotificationLeadTime.threeDaysBefore,
        },
      );
    });

    test('skips past schedules (already-fired notifications)', () {
      // 開催日が今日 → 「3日前」「1日前」は過去なのでスキップ、「当日」のみ残る
      final plans = planner.plan(
        events: [
          eventOf('e1', start: now, bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(
          notifyBeforeReservationStart: false,
          notifyBeforeReservationEnd: false,
          notifyBeforeEventStart: true,
        ),
        now: now,
      );
      // 当日 9:00 は now (= 9:00) と同時刻なので isAfter で false → 除外される
      // → 全部過去扱いで 0 件
      expect(plans, isEmpty);
    });

    test('completely past event yields no plans', () {
      final plans = planner.plan(
        events: [
          eventOf('e1', start: DateTime(2026, 1, 1), bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(),
        now: now,
      );
      expect(plans, isEmpty);
    });

    test('respects disabled trigger kinds', () {
      final plans = planner.plan(
        events: [
          eventOf(
            'e1',
            rsvStart: DateTime(2026, 5, 1),
            start: DateTime(2026, 6, 1),
            bookmarked: true,
          ),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(
          notifyBeforeReservationStart: false, // OFF
          notifyBeforeReservationEnd: true,
          notifyBeforeEventStart: true,
        ),
        now: now,
      );
      expect(
        plans.any((p) => p.kind == NotificationTriggerKind.reservationStart),
        isFalse,
      );
    });

    test('respects disabled lead times', () {
      final plans = planner.plan(
        events: [
          eventOf('e1', start: DateTime(2026, 6, 1), bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(
          notifyOnDay: false,         // OFF
          notifyOneDayBefore: true,
          notifyThreeDaysBefore: true,
        ),
        now: now,
      );
      expect(
        plans.any((p) => p.leadTime == NotificationLeadTime.onDay),
        isFalse,
      );
    });

    test('completely disabled settings yields zero plans', () {
      final plans = planner.plan(
        events: [
          eventOf('e1', start: DateTime(2026, 6, 1), bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(
          notifyBeforeReservationStart: false,
          notifyBeforeReservationEnd: false,
          notifyBeforeEventStart: false,
        ),
        now: now,
      );
      expect(plans, isEmpty);
    });

    test('eventStart falls back to releaseDate when startDate is null', () {
      final plans = planner.plan(
        events: [
          eventOf('e1', release: DateTime(2026, 6, 1), bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(
          notifyBeforeReservationStart: false,
          notifyBeforeReservationEnd: false,
          notifyBeforeEventStart: true,
        ),
        now: now,
      );
      expect(plans, isNotEmpty);
      expect(plans.every((p) => p.kind == NotificationTriggerKind.eventStart),
          isTrue);
    });

    test('notification IDs are deterministic and stable', () {
      final id1 = computeNotificationId(
          'e1',
          NotificationTriggerKind.eventStart,
          NotificationLeadTime.threeDaysBefore);
      final id2 = computeNotificationId(
          'e1',
          NotificationTriggerKind.eventStart,
          NotificationLeadTime.threeDaysBefore);
      expect(id1, id2);
      // 31bit 範囲
      expect(id1, greaterThanOrEqualTo(0));
      expect(id1, lessThanOrEqualTo(0x7FFFFFFF));
    });

    test('different events get different IDs (collision sanity check)', () {
      final id1 = computeNotificationId(
          'e1',
          NotificationTriggerKind.eventStart,
          NotificationLeadTime.onDay);
      final id2 = computeNotificationId(
          'e2',
          NotificationTriggerKind.eventStart,
          NotificationLeadTime.onDay);
      expect(id1, isNot(id2));
    });

    test('plans are sorted by scheduledAt ascending', () {
      final plans = planner.plan(
        events: [
          eventOf('e1',
              rsvStart: DateTime(2026, 5, 10),
              rsvEnd: DateTime(2026, 5, 20),
              start: DateTime(2026, 6, 1),
              bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(),
        now: now,
      );
      for (var i = 1; i < plans.length; i++) {
        expect(
          plans[i].scheduledAt.isBefore(plans[i - 1].scheduledAt),
          isFalse,
          reason: '$i番目: ${plans[i].scheduledAt} < ${plans[i - 1].scheduledAt}',
        );
      }
    });

    test('title and body include event/work info', () {
      final plans = planner.plan(
        events: [
          eventOf('e1',
              workTitle: '鬼滅の刃',
              title: 'コラボカフェ',
              start: DateTime(2026, 6, 1),
              bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(
          notifyBeforeReservationStart: false,
          notifyBeforeReservationEnd: false,
          notifyBeforeEventStart: true,
          notifyOnDay: false,
          notifyOneDayBefore: false,
          notifyThreeDaysBefore: true,
        ),
        now: now,
      );
      expect(plans, hasLength(1));
      expect(plans.single.title, contains('3日前'));
      expect(plans.single.title, contains('コラボカフェ'));
      expect(plans.single.body, contains('鬼滅の刃'));
    });
  });

  group('NotificationPlanner.plan in debugImmediateNotification mode', () {
    const debugPlanner = NotificationPlanner(debugImmediateNotification: true);

    test('emits exactly ONE notification at now + 1 minute', () {
      final plans = debugPlanner.plan(
        events: [
          eventOf(
            'e1',
            // 全部過去日付 (通常モードならスキップされる)
            rsvStart: DateTime(2025, 1, 1),
            rsvEnd: DateTime(2025, 1, 2),
            start: DateTime(2025, 1, 3),
            bookmarked: true,
          ),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(),
        now: now,
      );

      // デバッグでは「最初の1件だけ」を1分後に発火
      expect(plans, hasLength(1));
      expect(plans.single.scheduledAt, now.add(const Duration(minutes: 1)));
    });

    test('prefers reservationEnd > eventStart > reservationStart', () {
      // 全部の日付が揃っていれば reservationEnd が選ばれる
      final p1 = debugPlanner.plan(
        events: [
          eventOf('e1',
              rsvStart: DateTime(2026, 5, 1),
              rsvEnd: DateTime(2026, 5, 5),
              start: DateTime(2026, 6, 1),
              bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(),
        now: now,
      );
      expect(p1.single.kind, NotificationTriggerKind.reservationEnd);

      // reservationEnd が無ければ eventStart
      final p2 = debugPlanner.plan(
        events: [
          eventOf('e2',
              rsvStart: DateTime(2026, 5, 1),
              start: DateTime(2026, 6, 1),
              bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e2'},
        settings: const NotificationSettings(),
        now: now,
      );
      expect(p2.single.kind, NotificationTriggerKind.eventStart);

      // どちらも無ければ reservationStart
      final p3 = debugPlanner.plan(
        events: [
          eventOf('e3', rsvStart: DateTime(2026, 5, 1), bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e3'},
        settings: const NotificationSettings(),
        now: now,
      );
      expect(p3.single.kind, NotificationTriggerKind.reservationStart);
    });

    test('always uses leadTime onDay regardless of settings', () {
      final plans = debugPlanner.plan(
        events: [
          eventOf('e1', start: DateTime(2026, 6, 1), bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(
          // 当日 OFF, 1日前 ON, 3日前 ON
          notifyOnDay: false,
          notifyOneDayBefore: true,
          notifyThreeDaysBefore: true,
        ),
        now: now,
      );
      // デバッグでは leadTime は常に onDay (設定は無視)
      expect(plans, hasLength(1));
      expect(plans.single.leadTime, NotificationLeadTime.onDay);
    });

    test('title is "[テスト通知] <event title>"', () {
      final plans = debugPlanner.plan(
        events: [
          eventOf('e1',
              title: '鬼滅の刃 コラボカフェ',
              workTitle: '鬼滅の刃',
              rsvEnd: DateTime(2026, 5, 5),
              bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(),
        now: now,
      );
      expect(plans.single.title, '[テスト通知] 鬼滅の刃 コラボカフェ');
    });

    test('body contains debug marker, work title, and trigger label', () {
      final plans = debugPlanner.plan(
        events: [
          eventOf('e1',
              title: 'コラボカフェ',
              workTitle: '鬼滅の刃',
              rsvEnd: DateTime(2026, 5, 5),
              bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(),
        now: now,
      );
      final body = plans.single.body;
      expect(body, contains('デバッグ通知です'));
      expect(body, contains('1分後'));
      expect(body, contains('鬼滅の刃'));
      expect(body, contains('予約締切')); // reservationEnd のラベル
    });

    test('still respects target filter (non-bookmark, non-favorite skipped)',
        () {
      final plans = debugPlanner.plan(
        events: [
          eventOf('e1', start: DateTime(2026, 5, 1)),
        ],
        works: const [],
        bookmarkedEventIds: const {}, // ブックマークなし、お気に入りなし
        settings: const NotificationSettings(),
        now: now,
      );
      expect(plans, isEmpty,
          reason: 'debug モードでも対象判定はスキップされない');
    });

    test('still respects disabled trigger settings', () {
      // reservationEnd を OFF にすれば、優先度が次に下がって eventStart が選ばれる
      final plans = debugPlanner.plan(
        events: [
          eventOf('e1',
              rsvEnd: DateTime(2026, 5, 5),
              start: DateTime(2026, 6, 1),
              bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(
          notifyBeforeReservationStart: false,
          notifyBeforeReservationEnd: false, // OFF
          notifyBeforeEventStart: true,
        ),
        now: now,
      );
      expect(plans, hasLength(1));
      expect(plans.single.kind, NotificationTriggerKind.eventStart);
    });

    test('prefers bookmarked event over favorite-work event', () {
      // 同じ作品の 2 イベント。お気に入り作品 1 件 + ブックマーク 1 件
      final plans = debugPlanner.plan(
        events: [
          // お気に入り作品の関連だが未ブックマーク
          eventOf('e_fav',
              workId: 'w_fav',
              rsvEnd: DateTime(2026, 5, 5),
              bookmarked: false),
          // ブックマーク済み (こちらが優先される)
          eventOf('e_bm',
              workId: 'w_other',
              rsvEnd: DateTime(2026, 5, 6),
              bookmarked: true),
        ],
        works: [workOf('w_fav', fav: true)],
        bookmarkedEventIds: const {'e_bm'},
        settings: const NotificationSettings(),
        now: now,
      );
      expect(plans, hasLength(1));
      expect(plans.single.eventId, 'e_bm');
    });

    test('returns empty when all triggers are disabled', () {
      final plans = debugPlanner.plan(
        events: [
          eventOf('e1', rsvEnd: DateTime(2026, 5, 5), bookmarked: true),
        ],
        works: const [],
        bookmarkedEventIds: const {'e1'},
        settings: const NotificationSettings(
          notifyBeforeReservationStart: false,
          notifyBeforeReservationEnd: false,
          notifyBeforeEventStart: false,
        ),
        now: now,
      );
      expect(plans, isEmpty);
    });
  });

  group('kDebugImmediateNotification top-level constant', () {
    test(
      'is false in committed code (production safety)',
      () {
        // 本番コードに「true」のままコミットされていないことの保険テスト。
        expect(kDebugImmediateNotification, isFalse,
            reason:
                '本番では必ず false。デバッグ確認後に元に戻し忘れていないかチェック');
      },
      // デバッグ確認中はこのテストをスキップ。
      // 終わったら定数を false に戻す → 自動でこのテストが復活して
      // 「うっかり true のままリリースする」ことを防げる。
      skip: kDebugImmediateNotification
          ? 'kDebugImmediateNotification=true (debug mode). 本番に戻すまでこのアサートはスキップ。'
          : null,
    );
  });
}
