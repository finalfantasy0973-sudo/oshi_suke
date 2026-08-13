import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_planner.dart';

/// 推しスケのローカル通知サービス。
///
/// 役割:
///  - flutter_local_notifications プラグインの初期化
///  - timezone 初期化 (Asia/Tokyo)
///  - 通知チャンネル作成 (Android 8+)
///  - 通知権限のリクエスト (Android 13+ / iOS)
///  - [PlannedNotification] のリストを受け取って端末に登録 / 既存を全削除
///
/// 注意: テスト環境では native plugin が動かない場合があるので、
/// 失敗を握りつぶすラッパとして実装している。
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Android の通知チャンネル ID。チャンネル設定変更は新 ID で行う。
  static const _channelId = 'oshi_suke_main_v1';
  static const _channelName = '推しスケ通知';
  static const _channelDescription = '予約開始・締切・開催開始のリマインダ';

  bool _initialized = false;

  /// Future.delayed ベースの擬似 1 分後タイマー (デバッグ用)。
  /// プロセスが生きている間だけ動く。AlarmManager / Doze をバイパスして
  /// `_plugin.show()` 経路だけを検証するためのもの。
  Timer? _pseudoTimer;
  DateTime? _pseudoFiresAt;

  /// アプリ起動時に1度だけ呼び出す。
  Future<void> init() async {
    if (_initialized) return;

    // タイムゾーン (国内アプリなので Asia/Tokyo を採用)
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
    } catch (e) {
      debugPrint('[NotificationService] timezone init failed: $e');
    }

    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _onTap,
      );

      // Android: 通知チャンネル作成 (Android 8+)
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );

      _initialized = true;
      debugPrint('[NotificationService] initialized');
    } catch (e, st) {
      debugPrint('[NotificationService] init failed: $e');
      debugPrintStack(stackTrace: st, maxFrames: 3);
    }
  }

  /// Android 13+ / iOS の通知権限をユーザーに求める。
  ///
  /// 戻り値は許可されたかどうか (Android 12 以下では常に true)。
  Future<bool> requestPermission() async {
    if (!_initialized) await init();

    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        debugPrint(
            '[NotificationService] Android notification permission: $granted');
        return granted ?? false;
      }
      if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('[NotificationService] requestPermission failed: $e');
    }
    return true; // それ以外のプラットフォームは true 扱い
  }

  /// 既存スケジュールを全消し → [plans] を新たに登録する。
  ///
  /// 「全消し+全張り直し」方針にしているのは、ブックマーク取り消し等で
  /// 古い通知を確実に消すため。件数が多くないので毎回まとめて再登録する。
  ///
  /// **スケジュールモード方針**:
  ///   推しスケは意図的に [AndroidScheduleMode.inexactAllowWhileIdle] を採用。
  ///   - exact alarm 権限 (Android 12+ で SCHEDULE_EXACT_ALARM) に依存しない
  ///   - Doze モード下では発火が数分〜十数分ズレる可能性を許容する
  ///   - 推しスケの通知は「朝 9 時前後」が目安なので、数分のズレは UX で問題ない
  ///   - exact 通知はデバッグパネルから明示的に試せる (本番では使わない)
  Future<void> applyPlan(List<PlannedNotification> plans) async {
    if (!_initialized) await init();

    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] cancelAll failed: $e');
    }

    if (plans.isEmpty) {
      debugPrint('[NotificationService] applyPlan: 通知0件 (全キャンセルのみ)');
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    var scheduled = 0;
    for (final p in plans) {
      try {
        await _plugin.zonedSchedule(
          p.id,
          p.title,
          p.body,
          tz.TZDateTime.from(p.scheduledAt, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: p.eventId,
        );
        scheduled++;
      } catch (e) {
        debugPrint(
            '[NotificationService] schedule failed (id=${p.id}, "${p.title}"): $e');
      }
    }

    debugPrint(
        '[NotificationService] applyPlan: ${plans.length}件のうち $scheduled 件をスケジュール');
  }

  /// 通知をすべてキャンセル (テストやログアウト時に使う)。
  Future<void> cancelAll() async {
    if (!_initialized) await init();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] cancelAll failed: $e');
    }
  }

  /// (デバッグ用) 端末側に予約済みの通知一覧。
  Future<List<PendingNotificationRequest>> pending() async {
    if (!_initialized) await init();
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('[NotificationService] pending failed: $e');
      return const [];
    }
  }

  /// 予約済み通知を見やすい文字列リストに整形 (デバッグパネル用)。
  ///
  /// PendingNotificationRequest には scheduledAt が含まれないため、
  /// id / title / body / payload のみ。実発火時刻は OS に問い合わせる手段がない。
  Future<List<String>> describePending({int limit = 30}) async {
    final list = await pending();
    return list.take(limit).map((p) {
      final title = (p.title?.isNotEmpty ?? false) ? p.title! : '(no title)';
      final payload =
          (p.payload?.isNotEmpty ?? false) ? ' [${p.payload}]' : '';
      return '#${p.id} $title$payload';
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────
  // デバッグ / 動作確認用
  // ─────────────────────────────────────────────────────────────────

  /// 通常スケジュールの ID と衝突しないよう、テスト通知用に高位 ID を予約。
  /// computeNotificationId は `& 0x7FFFFFFF` でハッシュを丸めるが、
  /// hashCode が ちょうど 0x7FFFFFF0/0x7FFFFFF1 になる確率は実質ゼロ。
  static const int testIdImmediate = 0x7FFFFFF0;
  static const int testIdScheduled = 0x7FFFFFF1;

  NotificationDetails _testNotificationDetails() => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max, // テストはとにかく目立たせる
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          // ヘッドアップ表示を出すため
          fullScreenIntent: false,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  /// 即時通知 (動作確認用)。
  /// `_plugin.show()` を直接叩く。チャンネル / 権限 / プラグイン疎通を一発検証。
  Future<bool> showImmediate({
    String title = '推しスケ テスト通知',
    String body = '即時通知の確認です',
  }) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        testIdImmediate,
        title,
        body,
        _testNotificationDetails(),
        payload: 'debug_immediate',
      );
      debugPrint('[NotificationService] showImmediate: OK ($title)');
      return true;
    } catch (e, st) {
      debugPrint('[NotificationService] showImmediate FAILED: $e');
      debugPrintStack(stackTrace: st, maxFrames: 3);
      return false;
    }
  }

  /// 1分後通知 (zonedSchedule のスモークテスト)。
  ///
  /// [forceExact] が true なら `exactAllowWhileIdle` を試みる
  /// (Android 12+ で SCHEDULE_EXACT_ALARM 権限が必要)。
  /// 権限が無い場合は自動的に `inexactAllowWhileIdle` にフォールバック。
  ///
  /// 戻り値: ScheduleAttemptResult (成否 + 採用された scheduledAt / mode を含む)。
  ///
  /// 注意: inexact モードは実発火が数分〜十数分遅れることがある (Doze モード等)。
  /// 推しスケの本番動作 (`applyPlan`) は意図的に inexact を使っている。
  Future<ScheduleAttemptResult> scheduleInOneMinute({
    bool forceExact = false,
    String title = '推しスケ テスト通知',
    String body = '1分後通知の確認です',
  }) async {
    if (!_initialized) await init();
    final scheduledAt = DateTime.now().add(const Duration(minutes: 1));

    var mode = forceExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    var fellBackToInexact = false;
    if (forceExact && Platform.isAndroid) {
      final ok = await canScheduleExactAlarms();
      if (!ok) {
        debugPrint(
            '[NotificationService] exact alarm 不許可。inexact にフォールバック');
        mode = AndroidScheduleMode.inexactAllowWhileIdle;
        fellBackToInexact = true;
      }
    }

    try {
      await _plugin.zonedSchedule(
        testIdScheduled,
        title,
        body,
        tz.TZDateTime.from(scheduledAt, tz.local),
        _testNotificationDetails(),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'debug_scheduled',
      );
      debugPrint('[NotificationService] scheduleInOneMinute OK');
      debugPrint('  scheduledAt = $scheduledAt');
      debugPrint('  mode        = $mode'
          '${fellBackToInexact ? " (forceExact から自動フォールバック)" : ""}');

      // 直後の pending 状態をログ出力 (本当に登録されたかの裏取り)
      try {
        final pending = await _plugin.pendingNotificationRequests();
        debugPrint('  pending     = ${pending.length}件');
        for (final p in pending) {
          debugPrint('    #${p.id}: "${p.title}"');
        }
      } catch (e) {
        debugPrint('  pending logging failed: $e');
      }

      return ScheduleAttemptResult(
        ok: true,
        scheduledAt: scheduledAt,
        mode: mode,
        fellBackToInexact: fellBackToInexact,
      );
    } catch (e, st) {
      debugPrint('[NotificationService] scheduleInOneMinute FAILED: $e');
      debugPrintStack(stackTrace: st, maxFrames: 3);
      return ScheduleAttemptResult(
        ok: false,
        scheduledAt: scheduledAt,
        mode: mode,
        fellBackToInexact: fellBackToInexact,
        error: '$e',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Future.delayed ベースの擬似 1 分後通知 (AlarmManager / Doze バイパス)
  // ─────────────────────────────────────────────────────────────────

  /// 1 分後にプロセス内 Timer で `showImmediate` を起こす擬似テスト。
  ///
  /// 動作前提:
  ///  - アプリプロセスが 1 分間生きていること (foreground or 直近 background)
  ///  - 端末が深い Doze に入る前 (画面 OFF 直後なら通常 OK)
  ///
  /// AlarmManager / 通知チャンネルの一部経路 / exact 権限を **完全にバイパス**
  /// して `_plugin.show()` 経路だけを検証できる。
  ///   - これすら届かない → SDK / 権限 / チャンネル系の問題
  ///   - これは届くが zonedSchedule は届かない → AlarmManager / Doze 系の問題
  ///
  /// 既存の擬似タイマーが armed なら一旦キャンセルして上書き。
  bool scheduleInOneMinuteViaTimer({
    String title = '推しスケ テスト通知',
    String body = '擬似1分後 (Future.delayed) からの通知です',
  }) {
    cancelPseudoTimer();
    final firesAt = DateTime.now().add(const Duration(minutes: 1));
    debugPrint(
        '[NotificationService] scheduleInOneMinuteViaTimer: fire at $firesAt (Timer-based)');
    _pseudoFiresAt = firesAt;
    _pseudoTimer = Timer(const Duration(minutes: 1), () async {
      _pseudoTimer = null;
      _pseudoFiresAt = null;
      final ok = await showImmediate(title: title, body: body);
      debugPrint('[NotificationService] viaTimer fired: showImmediate=$ok');
    });
    return true;
  }

  /// 擬似タイマーが現在 armed か。
  bool get pseudoTimerArmed =>
      _pseudoTimer != null && _pseudoTimer!.isActive;

  /// 擬似タイマーの発火予定時刻 (armed でなければ null)。
  DateTime? get pseudoFiresAt => pseudoTimerArmed ? _pseudoFiresAt : null;

  /// 擬似タイマーをキャンセル。
  void cancelPseudoTimer() {
    if (_pseudoTimer != null) {
      _pseudoTimer!.cancel();
      _pseudoTimer = null;
      _pseudoFiresAt = null;
      debugPrint('[NotificationService] pseudo timer canceled');
    }
  }

  /// テスト通知を取り消し (連打対策)。
  Future<void> cancelTestNotifications() async {
    if (!_initialized) await init();
    try {
      await _plugin.cancel(testIdImmediate);
      await _plugin.cancel(testIdScheduled);
    } catch (e) {
      debugPrint('[NotificationService] cancelTestNotifications failed: $e');
    }
  }

  /// Android: exact alarm が許可されているか (Android 12+ で重要)。
  /// API 31 未満では常に true 扱い。
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final result = await android?.canScheduleExactNotifications();
      return result ?? false;
    } catch (e) {
      debugPrint('[NotificationService] canScheduleExactAlarms failed: $e');
      return false;
    }
  }

  /// Android 12+ で exact alarm 権限が必要なときに呼ぶ。
  /// システム設定アプリへ誘導される (アプリ内ダイアログでは完結しない)。
  Future<bool> requestExactAlarmsPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await android?.requestExactAlarmsPermission();
      debugPrint(
          '[NotificationService] requestExactAlarmsPermission: $granted');
      return granted ?? false;
    } catch (e) {
      debugPrint(
          '[NotificationService] requestExactAlarmsPermission failed: $e');
      return false;
    }
  }

  /// 現在の権限・チャンネル・予約状況をまとめて取得。
  /// デバッグパネルで表示する用途。
  Future<NotificationDiagnostics> diagnostics() async {
    if (!_initialized) await init();
    bool? notificationsEnabled;
    bool? exactAlarmsAllowed;
    var channelExists = false;
    var pendingCount = 0;
    String? lastError;

    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        notificationsEnabled = await android?.areNotificationsEnabled();
        try {
          exactAlarmsAllowed = await android?.canScheduleExactNotifications();
        } catch (e) {
          // API 31 未満では実装が無いケース。null のままにしておく。
          debugPrint('[NotificationService] canScheduleExact unavailable: $e');
        }

        final channels = await android?.getNotificationChannels() ?? const [];
        channelExists = channels.any((c) => c.id == _channelId);
      } else if (Platform.isIOS) {
        // iOS は areNotificationsEnabled に相当する API なし。getNotificationAppLaunchDetails で代替判定可だが省略
        channelExists = true; // チャンネル概念なし
      }

      pendingCount = (await _plugin.pendingNotificationRequests()).length;
    } catch (e) {
      lastError = '$e';
      debugPrint('[NotificationService] diagnostics partial failure: $e');
    }

    final diag = NotificationDiagnostics(
      initialized: _initialized,
      platform: Platform.operatingSystem,
      notificationsEnabled: notificationsEnabled,
      exactAlarmsAllowed: exactAlarmsAllowed,
      channelExists: channelExists,
      channelId: _channelId,
      pendingNotificationCount: pendingCount,
      lastError: lastError,
    );
    debugPrint('[NotificationService] diagnostics → $diag');
    return diag;
  }

  /// 通知タップ時のハンドラ (現状はログ出力のみ)。
  ///
  /// TODO(future): payload (= eventId) を使って詳細画面へ遷移する。
  static void _onTap(NotificationResponse response) {
    debugPrint(
        '[NotificationService] tapped: actionId=${response.actionId}, payload=${response.payload}');
  }
}

/// `scheduleInOneMinute` の結果。
///
/// UI 側で「実際に何時に予約されたか」「inexact にフォールバックしたか」
/// を表示するために値オブジェクト化。
@immutable
class ScheduleAttemptResult {
  const ScheduleAttemptResult({
    required this.ok,
    required this.scheduledAt,
    required this.mode,
    required this.fellBackToInexact,
    this.error,
  });

  final bool ok;
  final DateTime scheduledAt;
  final AndroidScheduleMode mode;
  final bool fellBackToInexact;
  final String? error;

  @override
  String toString() => 'ScheduleAttemptResult('
      'ok=$ok, '
      'scheduledAt=$scheduledAt, '
      'mode=$mode, '
      'fellBackToInexact=$fellBackToInexact, '
      'error=$error)';
}

/// 通知サービスの状態スナップショット (デバッグパネル表示用)。
@immutable
class NotificationDiagnostics {
  const NotificationDiagnostics({
    required this.initialized,
    required this.platform,
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    required this.channelExists,
    required this.channelId,
    required this.pendingNotificationCount,
    required this.lastError,
  });

  /// init() 完了済みか。
  final bool initialized;

  /// 'android' / 'ios' / その他。
  final String platform;

  /// OS 側で通知を許可されているか (Android 13+)。null = 不明。
  final bool? notificationsEnabled;

  /// Android 12+ で exact alarm が許可されているか。null = 利用不可。
  final bool? exactAlarmsAllowed;

  /// 通知チャンネルが作成されているか。
  final bool channelExists;
  final String channelId;

  /// 端末に予約済みの通知件数。
  final int pendingNotificationCount;

  /// 取得時のエラー (あれば)。
  final String? lastError;

  @override
  String toString() => 'NotificationDiagnostics('
      'initialized=$initialized, '
      'platform=$platform, '
      'notificationsEnabled=$notificationsEnabled, '
      'exactAlarmsAllowed=$exactAlarmsAllowed, '
      'channelExists=$channelExists, '
      'pending=$pendingNotificationCount, '
      'lastError=$lastError)';
}
