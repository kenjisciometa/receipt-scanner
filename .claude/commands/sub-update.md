---
name: sub-update
description: 全サブモジュールを最新状態に更新する
user_invocable: true
---

# サブモジュール更新

全サブモジュールをリモートの最新状態に更新してください。

## 手順

1. `git submodule status` で現在の各サブモジュールの状態を確認する
2. `git submodule update --remote --merge` で全サブモジュールを最新に更新する
3. 更新後、再度 `git submodule status` で結果を確認する
4. 変更があった場合、どのサブモジュールが更新されたかを報告する
5. 更新内容のコミット・プッシュは行わない（必要な場合はユーザーが `/commit-push` を使う）
