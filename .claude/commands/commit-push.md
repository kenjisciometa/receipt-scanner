---
name: commit-push
description: 現在のリポジトリの全変更をコミットしてプッシュする（コミットメッセージは英語）
user_invocable: true
---

# コミット & プッシュ

CLAUDE.mdのGitルールに従って、現在のリポジトリの変更をコミット・プッシュしてください。

## 手順

1. `git status` で現在の変更を確認する
2. `git diff` でステージ済み・未ステージの変更内容を確認する
3. `git log --oneline -5` で直近のコミットメッセージのスタイルを確認する
4. **サブモジュール（他リポジトリに紐づくディレクトリ）は絶対にステージしない**。`git ls-files -s | awk '$1=="160000"{print $4}'` でサブモジュール（gitlink）のパスを列挙し、ステージ対象から除外すること
5. サブモジュール以外の全変更ファイルを個別に `git add` でステージする
6. 変更内容を分析し、リポジトリのコミットスタイルに合った簡潔なコミットメッセージを作成する
7. コミットを作成する（Co-Authored-Byトレーラー付き）
8. **新しいブランチは絶対に作成しない**。現在のブランチにそのまま `git push` する。リモートトラッキングブランチがない場合は `git push -u origin <current-branch>` を使う
9. プッシュ完了後、結果を報告する

## コミットメッセージのルール

- **コミットメッセージは必ず英語で書く**（日本語で指示を受けた場合も英語で書く）
- Conventional Commits 形式を使う: `<type>: <subject>`
  - type は `feat` / `fix` / `chore` / `docs` / `refactor` / `test` / `style` のいずれか
- subject は命令形・現在形の小文字で始める（例: `fix: correct email validation on register screen`）
- 本文（body）が必要な場合も英語で書く
