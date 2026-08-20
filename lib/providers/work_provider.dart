import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/remote_data_config.dart';
import '../models/work.dart';
import '../repositories/favorite_repository.dart';
import '../repositories/json_asset_work_repository.dart';
import '../repositories/remote_json_work_repository.dart';
import '../repositories/work_repository.dart';

/// 作品リポジトリの提供。
///
/// 取得チェーン:
///   1. [RemoteDataConfig.worksJsonUrl] が設定されていれば外部 URL から取得
///   2. 失敗 (タイムアウト / 非200 / JSON 不正) → assets/data/works.json
///   3. それも失敗 → mockWorks
///
/// 将来 Firestore / API に差し替える場合はここを書き換えるだけでよい。
final workRepositoryProvider = Provider<WorkRepository>((ref) {
  final asset = JsonAssetWorkRepository();
  final urlStr = RemoteDataConfig.worksJsonUrl;
  if (urlStr == null || urlStr.isEmpty) {
    return asset;
  }
  final repo = RemoteJsonWorkRepository(
    url: Uri.parse(urlStr),
    fallback: asset,
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// お気に入り・追加作品などの永続化リポジトリ。
/// 将来 Firestore に差し替える場合はここを書き換えるだけでよい。
final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return SharedPrefsFavoriteRepository();
});

/// 作品一覧の状態管理。
/// お気に入りON/OFF、通知ON/OFF、追加・削除をローカル状態で行い、
/// 変更のたびに [FavoriteRepository] へ保存する。
class WorksNotifier extends StateNotifier<List<Work>> {
  WorksNotifier(this._repository, this._favoriteRepository) : super(const []) {
    _load();
  }

  final WorkRepository _repository;
  final FavoriteRepository _favoriteRepository;

  /// 配信データ由来の作品ID。ユーザー追加作品・削除済み作品との区別に使う。
  Set<String> _catalogIds = const {};

  Future<void> _load() async {
    final works = await _repository.fetchAll();
    _catalogIds = {for (final w in works) w.id};
    final saved = await _favoriteRepository.load();
    if (saved == null) {
      // 初回起動: 配信JSONの isFavorite / notificationEnabled を種として保存。
      // 以後はローカル保存が唯一の正となる。
      state = works;
      _persist();
      return;
    }
    // ローカル優先: 配信JSON側のユーザー状態フィールドとローカル保存が
    // 食い違う場合、必ずローカル (ユーザー操作の結果) を採用する。
    Work restore(Work w) => w.copyWith(
          isFavorite: saved.favoriteWorkIds.contains(w.id),
          notificationEnabled:
              !saved.notificationDisabledWorkIds.contains(w.id),
        );
    state = [
      for (final w in works)
        if (!saved.removedWorkIds.contains(w.id)) restore(w),
      for (final w in saved.userWorks)
        if (!_catalogIds.contains(w.id)) restore(w),
    ];
  }

  /// 現在の状態をスナップショットとして保存する。
  void _persist() {
    final snapshot = FavoriteState(
      favoriteWorkIds: {
        for (final w in state)
          if (w.isFavorite) w.id,
      },
      notificationDisabledWorkIds: {
        for (final w in state)
          if (!w.notificationEnabled) w.id,
      },
      removedWorkIds: {
        for (final id in _catalogIds)
          if (!state.any((w) => w.id == id)) id,
      },
      userWorks: [
        for (final w in state)
          if (!_catalogIds.contains(w.id)) w,
      ],
    );
    // ignore: discarded_futures
    _favoriteRepository.save(snapshot);
  }

  void toggleFavorite(String workId) {
    state = [
      for (final w in state)
        if (w.id == workId) w.copyWith(isFavorite: !w.isFavorite) else w,
    ];
    _persist();
  }

  void toggleNotification(String workId) {
    state = [
      for (final w in state)
        if (w.id == workId)
          w.copyWith(notificationEnabled: !w.notificationEnabled)
        else
          w,
    ];
    _persist();
  }

  void addWork(Work work) {
    state = [...state, work];
    _persist();
  }

  void removeWork(String workId) {
    state = state.where((w) => w.id != workId).toList();
    _persist();
  }

  Work? findById(String workId) {
    for (final w in state) {
      if (w.id == workId) return w;
    }
    return null;
  }
}

final worksProvider =
    StateNotifierProvider<WorksNotifier, List<Work>>((ref) {
  return WorksNotifier(
    ref.watch(workRepositoryProvider),
    ref.watch(favoriteRepositoryProvider),
  );
});

/// お気に入り作品だけ。
final favoriteWorksProvider = Provider<List<Work>>((ref) {
  return ref.watch(worksProvider).where((w) => w.isFavorite).toList();
});
