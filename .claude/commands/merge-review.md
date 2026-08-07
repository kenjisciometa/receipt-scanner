---
name: merge-review
description: DevブランチとStageブランチを比較し、マージの安全性を検証する
user_invocable: true
---

# Dev → Stage マージレビュー

DevブランチをStageブランチにマージしても機能的に破綻しないか検証してください。

## 引数

- `$ARGUMENTS` が指定された場合、その値をサブプロジェクトのパスとして使用する（例: `ReactRestaurantPOS`）
- 指定がなければカレントディレクトリのリポジトリで実行する

## 手順

### 1. ブランチ状態の確認

```
git fetch origin
git log --oneline origin/stage..origin/dev    # dev にあって stage にない（マージ対象）
git log --oneline origin/dev..origin/stage    # stage にあって dev にない（逆方向）
git diff --stat origin/stage...origin/dev     # 変更ファイル概要
```

- コミット数、変更ファイル数、追加/削除行数をサマリーとして報告する
- stage にあって dev にないコミットがある場合は **マージコンフリクトのリスク** として警告する

### 2. 変更内容の分類

`git diff origin/stage...origin/dev --name-only` の結果を以下に分類する:

| カテゴリ | パターン例 |
|----------|-----------|
| DB/マイグレーション | `supabase/migrations/`, `*.sql` |
| API ルート | `src/app/api/` |
| UI コンポーネント | `src/components/`, `src/app/dashboard/`, `src/app/order/` |
| ビジネスロジック | `src/lib/`, `src/hooks/`, `src/utils/` |
| 設定/環境 | `.env*`, `next.config.*`, `package.json`, `tsconfig.json` |
| ドキュメント | `docs/`, `*.md` |
| その他 | 上記に該当しないもの |

### 3. 破壊的変更の検出

以下を重点的にチェックする:

#### 3a. DB マイグレーション
- 新しいマイグレーションファイルがあるか
- 既存テーブルの `ALTER TABLE DROP COLUMN`, `DROP TABLE` 等の破壊的 DDL がないか
- RLS ポリシーの変更がないか
- stage 側のマイグレーション履歴と競合しないか（タイムスタンプの順序）

#### 3b. API の破壊的変更
- エンドポイントの削除・リネーム
- レスポンス形状の変更（フィールド削除、型変更）
- 認証/認可要件の変更
- 新しい必須パラメータの追加

#### 3c. 環境変数・設定
- 新しい環境変数が追加されているか → stage 環境での設定が必要
- `package.json` の依存関係の変更 → デプロイ時のインストールが必要
- `next.config.*` の変更 → ビルド設定への影響

#### 3d. 共有コンポーネント/ライブラリ
- export されている関数・型のシグネチャ変更
- 共有 hook の戻り値の変更
- 共有ユーティリティの動作変更

### 4. 機能整合性チェック

変更された各機能について:
1. 関連するファイルをすべて読む（API + UI + DB + ロジック）
2. データフローが一貫しているか確認する
3. 新機能が既存機能と矛盾しないか確認する
4. Feature flag や条件分岐で制御されている場合、stage 環境での状態を確認する

### 5. コンフリクト予測

```
git merge-tree $(git merge-base origin/dev origin/stage) origin/stage origin/dev
```

- コンフリクトが予測される場合、該当ファイルと箇所を報告する
- 手動解決が必要な場合の方針を提案する

### 6. デプロイ前チェックリスト生成

マージ後に必要なアクションを洗い出す:
- [ ] 新しい環境変数の設定（変数名を列挙）
- [ ] DB マイグレーションの実行（ファイル名を列挙）
- [ ] 依存パッケージのインストール（変更があれば）
- [ ] Supabase Edge Function のデプロイ（変更があれば）
- [ ] キャッシュクリア / ビルドの再実行
- [ ] 動作確認が必要な画面・機能（リスト）

## 報告フォーマット

```
## Dev → Stage マージレビュー

### ブランチ状態
- dev が stage より **N コミット** 先行
- stage が dev より **N コミット** 先行（逆方向）
- 変更ファイル数: N files changed, +X insertions, -Y deletions

### 変更内容サマリー
（カテゴリ別のファイル一覧）

### 破壊的変更: ✅ なし / ⚠️ あり
（ある場合は詳細を列挙）

### コンフリクト: ✅ なし / ⚠️ 予測あり
（ある場合は該当ファイルと解決方針）

### 機能整合性: ✅ 問題なし / ⚠️ 要確認
（問題がある場合は詳細）

### デプロイ前チェックリスト
- [ ] ...

### 総合判定: ✅ マージ可能 / ⚠️ 条件付きで可能 / ❌ マージ非推奨
（理由を簡潔に）
```
