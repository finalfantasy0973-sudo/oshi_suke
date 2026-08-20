import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oshi_suke/app.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ja_JP', null);
    // テスト環境には端末ストレージが無いため、インメモリ実装に差し替える
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots and shows bottom navigation', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: OshiSukeApp()),
    );
    await tester.pump();

    // 下部ナビゲーションのラベルが見えること
    expect(find.text('ホーム'), findsWidgets);
    expect(find.text('マイ作品'), findsOneWidget);
    expect(find.text('カレンダー'), findsOneWidget);
    expect(find.text('検索'), findsOneWidget);
    expect(find.text('ブックマーク'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
