/// 推しスケのリモートデータ設定。
///
/// **使い方は超シンプル**:
///
///   1) 外部 URL でデータをホスティングする (例: GitHub Pages / Firebase Hosting)
///   2) 下の [baseUrl] に **その URL の "ディレクトリ部分" だけ** を書き込む
///   3) 完了。`works.json` / `events.json` は自動的にぶら下がりで取得される
///
/// `null` のままだと Remote 取得をスキップして、
/// `assets/data/*.json` → `mock` の順でフォールバックする。
///
/// 取得チェーン:
///
///   [Remote] baseUrl + path  →  [Asset] assets/data/*.json  →  [Mock]
///
/// 詳細仕様は `docs/json_format.md` を参照。
class RemoteDataConfig {
  RemoteDataConfig._();

  // ---------------------------------------------------------------------------
  // ★★★ ここを書き換えるだけで Remote 有効化 ★★★
  //
  // 例: GitHub Pages を使う場合
  //   static const String? baseUrl = 'https://your-org.github.io/oshi-suke-data';
  //
  // 例: Firebase Hosting
  //   static const String? baseUrl = 'https://your-project.web.app/oshi-suke';
  //
  // 例: 自前 / Cloud Storage / S3 等
  //   static const String? baseUrl = 'https://example.com/oshi-suke';
  //
  // null のままだと Remote をスキップして asset → mock のみで動作する。
  // ---------------------------------------------------------------------------
  //
  // 現在: GitHub Pages (finalfantasy0973-sudo/oshi_suke リポジトリの public_data フォルダ) を使用。
  //   - works.json  : https://finalfantasy0973-sudo.github.io/oshi_suke/public_data/works.json
  //   - events.json : https://finalfantasy0973-sudo.github.io/oshi_suke/public_data/events.json
  //
  // Remote を無効化したい場合はこの値を `null` に戻すだけで OK
  // (型は将来の null 切替を残すため `String?` のまま維持する)。
  // ignore: unnecessary_nullable_for_final_variable_declarations
  static const String? baseUrl =
      'https://finalfantasy0973-sudo.github.io/oshi_suke/public_data';

  /// baseUrl 配下の works.json への相対パス。
  static const String worksPath = '/works.json';

  /// baseUrl 配下の events.json への相対パス。
  static const String eventsPath = '/events.json';

  /// works.json のフル URL (baseUrl が null なら null)。
  ///
  /// 末尾スラッシュは許容する (`baseUrl` の末尾と `worksPath` の先頭が
  /// 両方スラッシュでも 1 つに正規化)。
  static String? get worksJsonUrl => _join(baseUrl, worksPath);

  /// events.json のフル URL (baseUrl が null なら null)。
  static String? get eventsJsonUrl => _join(baseUrl, eventsPath);

  /// HTTP 取得のタイムアウト。これを超えるとフォールバック。
  static const Duration networkTimeout = Duration(seconds: 6);

  /// User-Agent ヘッダ。サーバ側で識別したい場合に使う。
  static const String userAgent = 'OshiSuke/1.0 (Flutter; +https://example.com)';

  /// `baseUrl + path` の安全な連結 (`//` の二重スラッシュは 1 つに正規化)。
  static String? _join(String? base, String path) {
    if (base == null || base.isEmpty) return null;
    final b = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }
}
