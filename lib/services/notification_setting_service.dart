import 'package:flutter/foundation.dart';

/// 通知のリードタイム (何日前に通知を出すか)。
///
/// 現在は 当日(0) / 1日前 / 3日前 の3パターン。
enum NotificationLeadTime {
  onDay,
  oneDayBefore,
  threeDaysBefore,
}

extension NotificationLeadTimeX on NotificationLeadTime {
  /// 0 / 1 / 3 (日数)
  int get days {
    switch (this) {
      case NotificationLeadTime.onDay:
        return 0;
      case NotificationLeadTime.oneDayBefore:
        return 1;
      case NotificationLeadTime.threeDaysBefore:
        return 3;
    }
  }

  String get label {
    switch (this) {
      case NotificationLeadTime.onDay:
        return '当日';
      case NotificationLeadTime.oneDayBefore:
        return '1日前';
      case NotificationLeadTime.threeDaysBefore:
        return '3日前';
    }
  }
}

/// 通知の対象となる「日付の種類」。1イベントにつき最大3種類。
enum NotificationTriggerKind {
  /// 予約開始日
  reservationStart,

  /// 予約締切日
  reservationEnd,

  /// 開催開始日 (発売日も含む)
  eventStart,
}

/// 通知設定。
///
/// 取り扱い:
///   - 「どの種類のイベント日付について通知するか」を 3 つの bool で
///   - 「何日前に通知するか」を 3 つの bool で (当日/1日前/3日前)
/// この 2 軸の AND で実際の通知時刻が決まる。
@immutable
class NotificationSettings {
  const NotificationSettings({
    this.notifyBeforeReservationStart = true,
    this.notifyBeforeReservationEnd = true,
    this.notifyBeforeEventStart = true,
    this.notifyOnDay = true,
    this.notifyOneDayBefore = true,
    this.notifyThreeDaysBefore = true,
  });

  // ── どの日付について通知するか ──
  final bool notifyBeforeReservationStart;
  final bool notifyBeforeReservationEnd;
  final bool notifyBeforeEventStart;

  // ── 何日前に通知するか (複数選択可) ──
  final bool notifyOnDay;
  final bool notifyOneDayBefore;
  final bool notifyThreeDaysBefore;

  /// 有効になっているリードタイムを集合で取得 (スケジューラ向け)。
  Set<NotificationLeadTime> get enabledLeadTimes => {
        if (notifyOnDay) NotificationLeadTime.onDay,
        if (notifyOneDayBefore) NotificationLeadTime.oneDayBefore,
        if (notifyThreeDaysBefore) NotificationLeadTime.threeDaysBefore,
      };

  /// 有効になっているトリガー種類を集合で取得。
  Set<NotificationTriggerKind> get enabledTriggers => {
        if (notifyBeforeReservationStart)
          NotificationTriggerKind.reservationStart,
        if (notifyBeforeReservationEnd)
          NotificationTriggerKind.reservationEnd,
        if (notifyBeforeEventStart) NotificationTriggerKind.eventStart,
      };

  /// 通知が完全に無効か (1つでも通知が予定されないか) を判定。
  bool get isCompletelyDisabled =>
      enabledTriggers.isEmpty || enabledLeadTimes.isEmpty;

  NotificationSettings copyWith({
    bool? notifyBeforeReservationStart,
    bool? notifyBeforeReservationEnd,
    bool? notifyBeforeEventStart,
    bool? notifyOnDay,
    bool? notifyOneDayBefore,
    bool? notifyThreeDaysBefore,
  }) {
    return NotificationSettings(
      notifyBeforeReservationStart:
          notifyBeforeReservationStart ?? this.notifyBeforeReservationStart,
      notifyBeforeReservationEnd:
          notifyBeforeReservationEnd ?? this.notifyBeforeReservationEnd,
      notifyBeforeEventStart:
          notifyBeforeEventStart ?? this.notifyBeforeEventStart,
      notifyOnDay: notifyOnDay ?? this.notifyOnDay,
      notifyOneDayBefore: notifyOneDayBefore ?? this.notifyOneDayBefore,
      notifyThreeDaysBefore:
          notifyThreeDaysBefore ?? this.notifyThreeDaysBefore,
    );
  }
}
