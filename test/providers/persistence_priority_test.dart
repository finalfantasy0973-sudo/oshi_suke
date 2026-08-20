import 'package:flutter_test/flutter_test.dart';

import 'package:oshi_suke/models/category.dart';
import 'package:oshi_suke/models/oshi_event.dart';
import 'package:oshi_suke/models/work.dart';
import 'package:oshi_suke/providers/event_provider.dart';
import 'package:oshi_suke/providers/work_provider.dart';
import 'package:oshi_suke/repositories/bookmark_repository.dart';
import 'package:oshi_suke/repositories/event_repository.dart';
import 'package:oshi_suke/repositories/favorite_repository.dart';
import 'package:oshi_suke/repositories/work_repository.dart';

/// ─── fake 実装 (インメモリ) ─────────────────────────────────────────────

class FakeEventRepository implements EventRepository {
  FakeEventRepository(this.events);
  final List<OshiEvent> events;

  @override
  Future<List<OshiEvent>> fetchAll() async => events;
}

class FakeWorkRepository implements WorkRepository {
  FakeWorkRepository(this.works);
  final List<Work> works;

  @override
  Future<List<Work>> fetchAll() async => works;
}

class FakeBookmarkRepository implements BookmarkRepository {
  FakeBookmarkRepository([this.stored]);

  /// null = 一度も保存されていない (初回起動)
  Set<String>? stored;

  @override
  Future<Set<String>?> load() async => stored;

  @override
  Future<void> save(Set<String> bookmarkedEventIds) async {
    stored = {...bookmarkedEventIds};
  }
}

class FakeFavoriteRepository implements FavoriteRepository {
  FakeFavoriteRepository([this.stored]);

  FavoriteState? stored;

  @override
  Future<FavoriteState?> load() async => stored;

  @override
  Future<void> save(FavoriteState state) async {
    stored = state;
  }
}

/// ─── テストデータ ──────────────────────────────────────────────────────

OshiEvent event(String id, {bool isBookmarked = false}) => OshiEvent(
      id: id,
      workId: 'w1',
      workTitle: '作品1',
      title: 'イベント$id',
      category: OshiCategory.goods,
      isBookmarked: isBookmarked,
      createdAt: DateTime(2026, 1, 1),
    );

/// 非同期の _load() 完了を待つ (fake はすぐ返るので数マイクロタスクで十分)
Future<void> pumpEventLoop() => Future<void>.delayed(Duration.zero);

void main() {
  group('ブックマークの優先順位 (ローカル優先)', () {
    test('配信JSONが isBookmarked=true でもローカルが false ならば false のまま',
        () async {
      // 配信側は true と言っているが、ユーザーはローカルで外している
      final notifier = EventsNotifier(
        FakeEventRepository([event('e1', isBookmarked: true)]),
        FakeBookmarkRepository(<String>{}), // 保存済み・e1 は含まれない
      );
      await pumpEventLoop();

      expect(notifier.state.single.isBookmarked, false,
          reason: '配信JSONがユーザーの「外した」操作を復活させてはならない');
    });

    test('ローカルに保存されたブックマークが復元される', () async {
      final notifier = EventsNotifier(
        FakeEventRepository([event('e1'), event('e2')]),
        FakeBookmarkRepository({'e2'}),
      );
      await pumpEventLoop();

      expect(notifier.findById('e1')!.isBookmarked, false);
      expect(notifier.findById('e2')!.isBookmarked, true);
    });

    test('初回起動 (ローカル未保存) は配信JSONの値を種として保存する', () async {
      final bookmarkRepo = FakeBookmarkRepository(); // stored = null
      final notifier = EventsNotifier(
        FakeEventRepository([event('e1', isBookmarked: true), event('e2')]),
        bookmarkRepo,
      );
      await pumpEventLoop();

      expect(notifier.findById('e1')!.isBookmarked, true);
      expect(bookmarkRepo.stored, {'e1'}, reason: '種がローカルに保存されること');
    });

    test('トグル操作が保存される', () async {
      final bookmarkRepo = FakeBookmarkRepository(<String>{});
      final notifier = EventsNotifier(
        FakeEventRepository([event('e1')]),
        bookmarkRepo,
      );
      await pumpEventLoop();

      notifier.toggleBookmark('e1');
      await pumpEventLoop();

      expect(bookmarkRepo.stored, {'e1'});
    });
  });

  group('作品状態の復元 (ローカル優先)', () {
    const catalogWork = Work(id: 'w1', title: '作品1', genre: 'アニメ');

    test('配信JSONが isFavorite=true でもローカルが false ならば false のまま',
        () async {
      final notifier = WorksNotifier(
        FakeWorkRepository(
            [catalogWork.copyWith(isFavorite: true)]),
        FakeFavoriteRepository(const FavoriteState()), // お気に入り無し
      );
      await pumpEventLoop();

      expect(notifier.state.single.isFavorite, false);
    });

    test('お気に入り・通知OFF・ユーザー追加作品が復元される', () async {
      const userWork = Work(id: 'w_user_1', title: '手動追加', genre: 'ゲーム');
      final notifier = WorksNotifier(
        FakeWorkRepository([catalogWork]),
        FakeFavoriteRepository(const FavoriteState(
          favoriteWorkIds: {'w1', 'w_user_1'},
          notificationDisabledWorkIds: {'w1'},
          userWorks: [userWork],
        )),
      );
      await pumpEventLoop();

      expect(notifier.state, hasLength(2));
      expect(notifier.findById('w1')!.isFavorite, true);
      expect(notifier.findById('w1')!.notificationEnabled, false);
      expect(notifier.findById('w_user_1')!.isFavorite, true);
    });

    test('削除した配信カタログ作品は再起動後も復活しない', () async {
      final notifier = WorksNotifier(
        FakeWorkRepository([catalogWork]),
        FakeFavoriteRepository(const FavoriteState(
          removedWorkIds: {'w1'},
        )),
      );
      await pumpEventLoop();

      expect(notifier.state, isEmpty);
    });

    test('作品の追加・削除・トグルが保存される', () async {
      final favRepo = FakeFavoriteRepository(const FavoriteState());
      final notifier = WorksNotifier(
        FakeWorkRepository([catalogWork]),
        favRepo,
      );
      await pumpEventLoop();

      notifier.addWork(
          const Work(id: 'w_user_1', title: '手動追加', genre: 'その他'));
      notifier.toggleFavorite('w1');
      notifier.removeWork('w1');
      await pumpEventLoop();

      expect(favRepo.stored!.userWorks.single.id, 'w_user_1');
      expect(favRepo.stored!.removedWorkIds, {'w1'});
      expect(favRepo.stored!.favoriteWorkIds, isEmpty);
    });
  });
}
