---
name: test
description: プロジェクトのテストを実行する
user_invocable: true
---

# テスト実行

プロジェクトのテストを実行してください。

## 手順

1. 変更されたファイルを `git diff --name-only` で特定する
2. 変更されたファイルがどのサブプロジェクトに属するか判断する:
   - `ReactRestaurantPOS/` → Next.js（npm test / jest）
   - `order_sys/` → Flutter（flutter test）
   - `shift-management-app/` → Flutter（flutter test）
   - その他 → 該当するテストランナーを使用
3. 該当サブプロジェクトのディレクトリに移動し、テストを実行する
4. テスト結果を報告する（成功数、失敗数、失敗の詳細）
5. 失敗したテストがあれば、原因の分析と修正案を提示する
