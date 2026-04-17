---
name: pr
description: 現在のブランチからPull Requestを作成する
user_invocable: true
---

# Pull Request 作成

現在のブランチからPull Requestを作成してください。

## 手順

1. `git branch --show-current` で現在のブランチ名を確認する
2. `git log main..HEAD --oneline` でmainブランチからの差分コミットを確認する
3. `git diff main...HEAD --stat` で変更ファイルの概要を確認する
4. 未プッシュのコミットがあれば `git push` する（新しいブランチは作らない）
5. コミット内容を分析し、適切なPRタイトルと説明を作成する
6. `gh pr create` でPRを作成する。フォーマット:
   - タイトル: 70文字以内
   - 本文: Summary（箇条書き）+ Test plan
7. 作成されたPRのURLを報告する
