import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidScheduleMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/event_provider.dart';
import '../../providers/notification_scheduler_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final scheduledCount = ref.watch(plannedNotificationsProvider).length;

    return Scaffold(
      appBar: AppBar(title: const Text('通知設定')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Hint(scheduledCount: scheduledCount),
          const SizedBox(height: 12),
          // ── デバッグ / 動作確認パネル (debug ビルドのみ表示) ──
          if (kDebugMode) ...[
            const _DebugPanel(),
            const SizedBox(height: 16),
          ],
          _Group(
            title: '通知する日付',
            icon: Icons.event_note_rounded,
            children: [
              _SettingTile(
                icon: Icons.event_available_outlined,
                title: '予約開始日について通知',
                subtitle: '予約が始まる前にお知らせします',
                value: settings.notifyBeforeReservationStart,
                onChanged: notifier.setNotifyBeforeReservationStart,
              ),
              _Divider(),
              _SettingTile(
                icon: Icons.alarm_outlined,
                title: '予約締切日について通知',
                subtitle: '予約締切が近づいたらお知らせします',
                value: settings.notifyBeforeReservationEnd,
                onChanged: notifier.setNotifyBeforeReservationEnd,
              ),
              _Divider(),
              _SettingTile(
                icon: Icons.celebration_outlined,
                title: '開催開始日について通知',
                subtitle: 'イベント開催・発売前にお知らせします',
                value: settings.notifyBeforeEventStart,
                onChanged: notifier.setNotifyBeforeEventStart,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Group(
            title: '通知タイミング (重ねて選択可)',
            icon: Icons.schedule_rounded,
            children: [
              _SettingTile(
                icon: Icons.today_outlined,
                title: '当日に通知',
                subtitle: '対象日の朝 9 時に通知します',
                value: settings.notifyOnDay,
                onChanged: notifier.setNotifyOnDay,
              ),
              _Divider(),
              _SettingTile(
                icon: Icons.history_outlined,
                title: '1日前に通知',
                subtitle: '対象日の前日 朝 9 時に通知します',
                value: settings.notifyOneDayBefore,
                onChanged: notifier.setNotifyOneDayBefore,
              ),
              _Divider(),
              _SettingTile(
                icon: Icons.update_outlined,
                title: '3日前に通知',
                subtitle: '対象日の 3 日前 朝 9 時に通知します',
                value: settings.notifyThreeDaysBefore,
                onChanged: notifier.setNotifyThreeDaysBefore,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _NoticeFooter(scheduledCount: scheduledCount),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.scheduledCount});
  final int scheduledCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active_outlined, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ローカル通知が有効です',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '通知対象は「ブックマーク済みイベント」または「お気に入り作品の関連イベント」です。\n'
                  '現在 $scheduledCount 件の通知が予約されています。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeFooter extends StatelessWidget {
  const _NoticeFooter({required this.scheduledCount});
  final int scheduledCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: Color(0xFF6B5C72)),
              const SizedBox(width: 6),
              Text(
                '予約済み通知: $scheduledCount 件',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B5C72),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '・通知は端末のローカルアラームで動作します (オフラインでも届きます)。\n'
            '・スケジュールは設定変更・お気に入り変更・ブックマーク変更のたびに自動で更新されます。\n'
            '・Android 13 以降は OS の通知許可が必要です (アプリ設定 → 通知 から確認できます)。',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF6B5C72),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 0.6),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: value ? AppColors.primary : const Color(0xFF6B5C72),
                size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF231A2A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF8A7A93),
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// =============================================================================
// 通知デバッグパネル (debug ビルドのみ表示)
//
// 「通知が来ない」を切り分けるためのテストツール。
//   - 権限 / チャンネル / 予約数の診断表示
//   - 即時通知ボタン (`_plugin.show()` 直叩き)
//   - 1分後通知ボタン (inexact / exact 切替)
//   - exact alarm 権限のシステム設定起動
// =============================================================================

class _DebugPanel extends ConsumerStatefulWidget {
  const _DebugPanel();

  @override
  ConsumerState<_DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends ConsumerState<_DebugPanel> {
  NotificationDiagnostics? _diag;
  List<String> _pending = const [];
  bool _busy = false;
  bool _showPending = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  NotificationService get _service =>
      ref.read(notificationServiceProvider);

  Future<void> _refresh() async {
    final d = await _service.diagnostics();
    final pending = await _service.describePending();
    if (!mounted) return;
    setState(() {
      _diag = d;
      _pending = pending;
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor:
              error ? AppColors.statusDeadline : AppColors.statusActive,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _runWithBusy(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
      _refresh();
    }
  }

  Future<void> _testImmediate() => _runWithBusy(() async {
        final ok = await _service.showImmediate();
        _snack(ok ? '即時通知を発火しました' : '即時通知の発火に失敗 (ログ参照)',
            error: !ok);
      });

  Future<void> _testScheduled({required bool exact}) => _runWithBusy(() async {
        final r = await _service.scheduleInOneMinute(forceExact: exact);
        if (r.ok) {
          final modeLabel = r.mode == AndroidScheduleMode.exactAllowWhileIdle
              ? 'exact'
              : 'inexact';
          final fb = r.fellBackToInexact ? '\n(exact 不許可で inexact に降格)' : '';
          _snack(
            '1分後に通知を予約しました ($modeLabel)\n'
            '${_fmtClock(r.scheduledAt)} 発火予定$fb',
          );
        } else {
          _snack(
            '通知予約に失敗: ${r.error ?? "(ログ参照)"}',
            error: true,
          );
        }
      });

  void _testPseudo() {
    _service.scheduleInOneMinuteViaTimer();
    final at = _service.pseudoFiresAt;
    _snack(at == null
        ? '擬似通知タイマーを開始しました'
        : '擬似通知を ${_fmtClock(at)} に発火予定 (アプリを開いたままにしてください)');
    // armed 表示更新のため
    if (mounted) setState(() {});
  }

  void _cancelPseudo() {
    _service.cancelPseudoTimer();
    _snack('擬似通知タイマーをキャンセルしました');
    if (mounted) setState(() {});
  }

  static String _fmtClock(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  Future<void> _requestNotifPermission() => _runWithBusy(() async {
        final ok = await _service.requestPermission();
        _snack(
          ok ? 'OS の通知を許可済みです' : 'OS 側で通知許可が拒否されています',
          error: !ok,
        );
      });

  Future<void> _requestExact() => _runWithBusy(() async {
        final ok = await _service.requestExactAlarmsPermission();
        _snack(
          ok
              ? 'exact alarm が許可されました'
              : 'システム設定で「アラームとリマインダー」を許可してください',
          error: !ok,
        );
      });

  Future<void> _cancelTests() => _runWithBusy(() async {
        await _service.cancelTestNotifications();
        _snack('テスト通知をキャンセルしました');
      });

  @override
  Widget build(BuildContext context) {
    final d = _diag;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
            child: Row(
              children: [
                const Icon(Icons.bug_report_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '通知デバッグ (debug ビルドのみ)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '診断を再取得',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _busy ? null : _refresh,
                ),
              ],
            ),
          ),
          // ─ 診断カード ─
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _DiagBlock(diag: d),
          ),
          const Divider(height: 0.6),
          // ─ ボタン群 ─
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TestButton(
                  label: '今すぐテスト通知',
                  icon: Icons.notifications_rounded,
                  primary: true,
                  busy: _busy,
                  onPressed: _testImmediate,
                ),
                const SizedBox(height: 8),
                _PseudoTimerButton(
                  armed: _service.pseudoTimerArmed,
                  firesAt: _service.pseudoFiresAt,
                  busy: _busy,
                  onArm: _testPseudo,
                  onCancel: _cancelPseudo,
                ),
                const SizedBox(height: 8),
                _TestButton(
                  label: '1分後テスト通知 (inexact)',
                  icon: Icons.schedule_rounded,
                  busy: _busy,
                  onPressed: () => _testScheduled(exact: false),
                ),
                const SizedBox(height: 8),
                _TestButton(
                  label: '1分後テスト通知 (exact)',
                  icon: Icons.alarm_rounded,
                  busy: _busy,
                  onPressed: () => _testScheduled(exact: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        icon: const Icon(Icons.shield_outlined, size: 16),
                        label: const Text('通知許可'),
                        onPressed: _busy ? null : _requestNotifPermission,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        icon: const Icon(Icons.access_alarms_outlined, size: 16),
                        label: const Text('exact 許可'),
                        onPressed: _busy ? null : _requestExact,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('テスト取消'),
                        onPressed: _busy ? null : _cancelTests,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ─ 予約一覧 (折りたたみ) ─
          const Divider(height: 0.6),
          InkWell(
            onTap: () => setState(() => _showPending = !_showPending),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _showPending
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '予約一覧 (${_pending.length} 件)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _pending.isEmpty
                  ? const Text(
                      '(端末側に予約済みの通知はありません)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A7A93),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final entry in _pending)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                entry,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF231A2A),
                                  height: 1.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

/// 擬似 1 分後通知のトグルボタン (armed 状態を表示)。
class _PseudoTimerButton extends StatelessWidget {
  const _PseudoTimerButton({
    required this.armed,
    required this.firesAt,
    required this.busy,
    required this.onArm,
    required this.onCancel,
  });

  final bool armed;
  final DateTime? firesAt;
  final bool busy;
  final VoidCallback onArm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (armed && firesAt != null) {
      final at = firesAt!;
      final hh = at.hour.toString().padLeft(2, '0');
      final mm = at.minute.toString().padLeft(2, '0');
      final ss = at.second.toString().padLeft(2, '0');
      return OutlinedButton.icon(
        onPressed: busy ? null : onCancel,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.statusDeadline,
          side: const BorderSide(color: AppColors.statusDeadline),
        ),
        icon: const Icon(Icons.timer_rounded, size: 16),
        label: Text('擬似タイマー予約中 ($hh:$mm:$ss) — タップで取消'),
      );
    }
    return OutlinedButton.icon(
      onPressed: busy ? null : onArm,
      icon: const Icon(Icons.timer_outlined, size: 16),
      label: const Text('1分後 擬似 (Future.delayed)'),
    );
  }
}

class _DiagBlock extends StatelessWidget {
  const _DiagBlock({required this.diag});
  final NotificationDiagnostics? diag;

  @override
  Widget build(BuildContext context) {
    if (diag == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '診断情報を取得中…',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B5C72)),
        ),
      );
    }
    final d = diag!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiagRow(
            label: 'プラットフォーム',
            value: d.platform,
            ok: true,
          ),
          _DiagRow(
            label: 'init() 完了',
            value: d.initialized ? 'OK' : 'NG',
            ok: d.initialized,
          ),
          _DiagRow(
            label: 'OS の通知許可',
            value: _ynLabel(d.notificationsEnabled),
            ok: d.notificationsEnabled ?? true, // null は不明扱いで素通り
          ),
          _DiagRow(
            label: 'exact alarm 許可',
            value: _ynLabel(d.exactAlarmsAllowed,
                unknownLabel: '対象外 (Android 11 以下)'),
            ok: d.exactAlarmsAllowed ?? true,
          ),
          _DiagRow(
            label: 'チャンネル',
            value: d.channelExists
                ? '${d.channelId} ✓'
                : '${d.channelId} (未作成)',
            ok: d.channelExists,
          ),
          _DiagRow(
            label: '予約済み通知数',
            value: '${d.pendingNotificationCount} 件',
            ok: true,
          ),
          if (d.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'エラー: ${d.lastError}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.statusDeadline,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _ynLabel(bool? v, {String unknownLabel = '不明'}) {
    if (v == null) return unknownLabel;
    return v ? 'はい' : 'いいえ';
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow({required this.label, required this.value, required this.ok});
  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
            size: 14,
            color: ok ? AppColors.statusActive : AppColors.statusDeadline,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B5C72),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF231A2A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
    if (primary) {
      return FilledButton(
        onPressed: busy ? null : onPressed,
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      child: child,
    );
  }
}
