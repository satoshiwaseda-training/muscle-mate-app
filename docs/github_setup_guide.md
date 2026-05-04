# GitHub リポジトリ接続 + Pages 公開ガイド

## 現状

- ローカル：`/Users/User/Desktop/Claude/muscle-mate-app`
- リモート想定：`https://github.com/satoshiwaseda-training/muscle-mate-app`
- ローカルは **git で管理されていない**（`.git` フォルダなし）
- リモートは **空 or 非公開** のいずれか

## 進め方の分岐

```
最初に確認: GitHub の muscle-mate-app リポジトリは存在しますか？

├─ 存在しない → ケース A：新規作成して push
├─ 存在する（中身が空に近い） → ケース B：今のローカルを上書き push
└─ 存在する（古いコードが入っている） → ケース C：先にバックアップ取得
```

---

## ケース A：新規作成して push（一番シンプル）

ブラウザでの操作 + ターミナル操作の組み合わせ。

### A-1. GitHub で空のリポジトリを作る（ブラウザ）

1. https://github.com/new を開く
2. 以下を入力：
   - Repository name: `muscle-mate-app`
   - Owner: `satoshiwaseda-training`
   - Visibility: **Public**（GitHub Pages を無料で使うなら必須）
   - 「Add a README file」「Add .gitignore」「Choose a license」は **すべてチェックを外す**
3. 「Create repository」を押す
4. 出てきた URL を確認（`https://github.com/satoshiwaseda-training/muscle-mate-app.git`）

### A-2. ローカルから push（ターミナル）

ターミナルで以下を順に実行：

```bash
cd /Users/User/Desktop/Claude/muscle-mate-app

# 機密ファイルを git 管理から除外
cat > .gitignore << 'EOF'
# Flutter
frontend/build/
frontend/.dart_tool/
frontend/.flutter-plugins
frontend/.flutter-plugins-dependencies
frontend/.packages
frontend/.pub-cache/
frontend/.pub/
frontend/ios/Pods/
frontend/ios/Flutter/Flutter.framework
frontend/ios/Flutter/Flutter.podspec

# Backend
backend/__pycache__/
backend/*.pyc
backend/.venv/
backend/venv/
backend/.pytest_cache/
backend/pytest-cache-files-*

# 環境変数（API キー等が入る可能性）
.env
*.env
backend/.env

# OS
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/
*.iml

# ログ
*.log
EOF

# Git 初期化
git init
git branch -M main
git add .
git commit -m "Initial commit: Muscle Mate v1.0 提出計画書 v1.3 反映済み"

# リモート設定
git remote add origin https://github.com/satoshiwaseda-training/muscle-mate-app.git

# push
git push -u origin main
```

### A-3. GitHub Pages を有効化（ブラウザ）

1. https://github.com/satoshiwaseda-training/muscle-mate-app/settings/pages を開く
2. **Source** を「Deploy from a branch」にする
3. **Branch** で「main」を選び、フォルダで「`/docs`」を選ぶ
4. 「Save」を押す
5. 30 秒〜1 分待ってから次の URL を開く：
   - https://satoshiwaseda-training.github.io/muscle-mate-app/

「プライバシーポリシー」「サポート」のリンクが表示され、クリックして本文が見えれば成功。

---

## ケース B：既存リポジトリ（中身が空に近い）に上書き push

A-2 と同じだが、一度リモートを取り込んでからマージする：

```bash
cd /Users/User/Desktop/Claude/muscle-mate-app

# まずローカルを git 化（A-2 の .gitignore も同じものを作成）
git init
git branch -M main
git remote add origin https://github.com/satoshiwaseda-training/muscle-mate-app.git

# リモートの内容を取り込む
git fetch origin
git reset --soft origin/main  # ←リモートの履歴を引き継ぐ

# 全部 add してコミット
git add .
git commit -m "Update: v1.0 提出計画書 v1.3 反映"
git push origin main
```

---

## ケース C：既存リポジトリに別バージョンが入っている

中身がぶつかる可能性があるので、まず GitHub の中身をローカルの別フォルダに取得して比較：

```bash
cd /tmp
git clone https://github.com/satoshiwaseda-training/muscle-mate-app.git github-version

# Claude にどう統合するか相談
diff -r /tmp/github-version /Users/User/Desktop/Claude/muscle-mate-app | head -50
```

その後、Claude に diff を見せてください。どこをどう統合するか個別に判断します。

---

## トラブルシューティング

### 「Permission denied (publickey)」エラーが出る
HTTPS で push しているはずなので発生しないはずですが、出たら：
- GitHub のパスワードではなく **Personal Access Token** が必要です
- https://github.com/settings/tokens → 「Generate new token (classic)」
- Scope は `repo` だけチェック
- 生成された文字列をパスワード代わりに入力

### 「remote: Repository not found」エラー
- リポジトリの URL が間違っている
- リポジトリが Private で認証情報がない（上記 PAT で解決）

### `git push` で大量のファイルがアップロードされる
これは正常です。初回だけ全ファイルを上げるので時間がかかります（数分）。
