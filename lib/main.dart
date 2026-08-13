import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'providers/notification_scheduler_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 日本語ロケールデータの初期化 (DateFormat('...', 'ja_JP') 用)
  await initializeDateFormatting('ja_JP', null);

  final container = ProviderContainer();

  // ローカル通知の初期化 (timezone 設定 + plugin init + チャンネル作成)。
  // 失敗しても致命傷ではない (内部で握り潰してログのみ)。
  final notif = container.read(notificationServiceProvider);
  await notif.init();

  // Android 13+ の通知許可ダイアログを起動直後に出す (拒否されてもアプリは動く)。
  // ユーザーが拒否した場合は通知設定画面のボタンから再リクエスト可能にする予定。
  // ignore: discarded_futures
  notif.requestPermission();

  // 通知スケジューラを購読開始 → イベント/お気に入り/ブックマーク/設定の
  // どれかが変わるたびに自動で再スケジュールが走る。
  container.read(notificationSchedulerProvider);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OshiSukeApp(),
    ),
  );
}
