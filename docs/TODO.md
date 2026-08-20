# TODO

- 配信JSON (works.json / events.json) にユーザー状態フィールド (`isBookmarked` / `isFavorite` / `notificationEnabled`) が存在するのは設計上の問題。配信データからこれらを除去し、ユーザー状態はローカル保存 (リポジトリ層) に一本化する。現状はローカル優先の実装で回避している。
