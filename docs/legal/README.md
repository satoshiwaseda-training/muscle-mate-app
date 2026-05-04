# 公開法務ドキュメント (GitHub Pages)

このフォルダの HTML ファイルは GitHub Pages として公開され、App Store Connect に登録される URL のソースになります。

## 公開 URL（GitHub Pages 有効化後）

| ファイル | 公開 URL |
|---|---|
| `../index.html` | https://satoshiwaseda-training.github.io/muscle-mate-app/ |
| `privacy_policy.html` | https://satoshiwaseda-training.github.io/muscle-mate-app/legal/privacy_policy.html |
| `support.html` | https://satoshiwaseda-training.github.io/muscle-mate-app/legal/support.html |

## 編集ルール（重要）

**プライバシーポリシーの本文は `privacy_policy_v1.md` を唯一のソースとして扱います。** アプリ内画面（`frontend/lib/screens/privacy_policy_screen.dart`）と HTML（`privacy_policy.html`）の本文は完全一致させること。差分が出ると App Store 審査で「アプリ内文言と公開ポリシーの矛盾」として指摘されます。

更新フロー：
1. `privacy_policy_v1.md` を編集（最終更新日も更新）
2. アプリ内 `privacy_policy_screen.dart` の `_section` 引数を Markdown に合わせて修正
3. `privacy_policy.html` を Markdown に合わせて修正
4. push して GitHub Pages の反映を待つ（30 秒〜 1 分）
5. アプリも再ビルド（dart-define を変えたとき）
