import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/event_status.dart';
import '../models/oshi_event.dart';
import '../providers/event_provider.dart';
import '../theme/app_theme.dart';
import 'category_chip.dart';
import 'status_badge.dart';

/// ホーム・検索・ブックマーク等で共通利用するイベントカード。
class EventCard extends ConsumerWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  final OshiEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(eventStatusProvider(event));
    final fmt = DateFormat('M/d');

    final rangeText = _rangeText(event, fmt);
    final reservationText = _reservationText(event, fmt);
    final daysHint = _daysHint(event, status);

    // 旧実装は `IntrinsicHeight + Row(stretch) + Wrap` の組み合わせで
    // Wrap が 2 行になるとき intrinsic 高さが過小評価され、Column が
    // 親の高さ制約を超えて RenderFlex overflow を起こしていた。
    //
    // 解消: Stack を使い、コンテンツ (Padding+Column) の自然高さで Stack 高さを
    // 決定 → カバーは Positioned(top:0, bottom:0, width:110) で縦いっぱいに
    // 自動ストレッチ。intrinsic ベースの計算が不要になり overflow が起きない。
    const coverWidth = 110.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outline, width: 0.6),
            ),
            child: Stack(
              children: [
                // ── 右側コンテンツ (左に coverWidth 分の余白を確保) ──
                // この Column の自然高さが Stack 全体の高さを決める。
                Padding(
                  padding:
                      const EdgeInsets.only(left: coverWidth),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event.workTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            _BookmarkButton(event: event),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            height: 1.3,
                            color: Color(0xFF231A2A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            StatusBadge(status: status, dense: true),
                            CategoryChip(
                                category: event.category, dense: true),
                            if (event.hasOnlineShop)
                              const _MetaChip(
                                icon: Icons.shopping_cart_outlined,
                                label: '通販',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (rangeText != null)
                          _DateRow(
                            icon: Icons.event_outlined,
                            text: rangeText,
                          ),
                        if (reservationText != null)
                          _DateRow(
                            icon: Icons.alarm_outlined,
                            text: reservationText,
                            highlight:
                                status == EventStatus.deadlineSoon,
                          ),
                        if (event.location != null)
                          _DateRow(
                            icon: Icons.place_outlined,
                            text: event.location!,
                            muted: true,
                          ),
                        if (daysHint != null) ...[
                          const SizedBox(height: 6),
                          _DaysHintPill(
                            text: daysHint.text,
                            color: daysHint.color,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // ── 左カバー (top:0/bottom:0/width:coverWidth) ──
                // Stack 高さに合わせて自動で縦ストレッチされるため、
                // 旧 IntrinsicHeight 相当の見た目を保ちつつ overflow フリー。
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: coverWidth,
                  child: _CoverArea(
                    category: event.category,
                    status: status,
                    eventId: event.id,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _rangeText(OshiEvent e, DateFormat fmt) {
    if (e.startDate != null && e.endDate != null) {
      return '開催 ${fmt.format(e.startDate!)} 〜 ${fmt.format(e.endDate!)}';
    }
    if (e.startDate != null) return '開催 ${fmt.format(e.startDate!)}';
    if (e.releaseDate != null) return '発売 ${fmt.format(e.releaseDate!)}';
    return null;
  }

  static String? _reservationText(OshiEvent e, DateFormat fmt) {
    if (e.reservationStartDate != null && e.reservationEndDate != null) {
      return '予約 ${fmt.format(e.reservationStartDate!)} 〜 ${fmt.format(e.reservationEndDate!)}';
    }
    if (e.reservationEndDate != null) {
      return '予約締切 ${fmt.format(e.reservationEndDate!)}';
    }
    if (e.reservationStartDate != null) {
      return '予約開始 ${fmt.format(e.reservationStartDate!)}';
    }
    return null;
  }

  static _DaysHint? _daysHint(OshiEvent e, EventStatus status) {
    final today =
        DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    DateTime trunc(DateTime d) => DateTime(d.year, d.month, d.day);

    switch (status) {
      case EventStatus.deadlineSoon:
        final end = e.reservationEndDate;
        if (end == null) return null;
        final days = trunc(end).difference(today).inDays;
        return _DaysHint(
          text: days <= 0 ? '本日が予約締切！' : 'あと$days日で予約締切',
          color: AppColors.statusDeadline,
        );
      case EventStatus.upcoming:
        final start = e.startDate ?? e.releaseDate;
        if (start == null) return null;
        final days = trunc(start).difference(today).inDays;
        if (days <= 0) return null;
        return _DaysHint(
          text: 'あと$days日で開始',
          color: AppColors.statusUpcoming,
        );
      case EventStatus.reservationBefore:
        final start = e.reservationStartDate;
        if (start == null) return null;
        final days = trunc(start).difference(today).inDays;
        if (days <= 0) return null;
        return _DaysHint(
          text: 'あと$days日で予約開始',
          color: AppColors.statusBefore,
        );
      case EventStatus.active:
        final end = e.endDate;
        if (end == null) return null;
        final days = trunc(end).difference(today).inDays;
        return _DaysHint(
          text: days <= 0 ? '本日最終日' : '残り$days日',
          color: AppColors.statusActive,
        );
      case EventStatus.reservationOpen:
      case EventStatus.ended:
        return null;
    }
  }
}

class _DaysHint {
  const _DaysHint({required this.text, required this.color});
  final String text;
  final Color color;
}

class _CoverArea extends StatelessWidget {
  const _CoverArea({
    required this.category,
    required this.status,
    required this.eventId,
  });

  final OshiCategory category;
  final EventStatus status;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    // eventId のハッシュからカテゴリパレットを選んでバリエーションを出す
    final palette = AppGradients.categoryPalette[
        eventId.hashCode.abs() % AppGradients.categoryPalette.length];

    // 親 (Positioned with top:0/bottom:0/width:110) が幅と縦ストレッチを
    // 与えるので、ここでは追加の SizedBox 制約は不要。
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette,
            ),
          ),
          child: Center(
            child: Icon(
              category.icon,
              size: 44,
              color: AppColors.primaryDark.withValues(alpha: 0.55),
            ),
          ),
        ),
        // 左下にステータスのカラーピル (内容に合わせて自然サイズ)
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: status.color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.icon, size: 11, color: Colors.white),
                const SizedBox(width: 3),
                Text(
                  status.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BookmarkButton extends ConsumerWidget {
  const _BookmarkButton({required this.event});
  final OshiEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: 'ブックマーク',
      icon: Icon(
        event.isBookmarked
            ? Icons.bookmark_rounded
            : Icons.bookmark_border_rounded,
        color: event.isBookmarked ? AppColors.primary : const Color(0xFFB1A4B8),
        size: 22,
      ),
      onPressed: () {
        ref.read(eventsProvider.notifier).toggleBookmark(event.id);
      },
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF6B5C72)),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF6B5C72),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.icon,
    required this.text,
    this.highlight = false,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final bool highlight;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    Color color;
    if (highlight) {
      color = AppColors.statusDeadline;
    } else if (muted) {
      color = const Color(0xFF8A7A93);
    } else {
      color = const Color(0xFF4A3D52);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysHintPill extends StatelessWidget {
  const _DaysHintPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
