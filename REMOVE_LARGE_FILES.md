# 大きなSQLファイルをGit履歴から削除する手順

## 問題
以下の大きなSQLファイル（約547MB）がGit履歴に含まれており、GitHubへのプッシュが拒否されています：
- `complete_schema_and_data_09120733.sql` (547.56 MB)
- `complete_schema_and_data_09121520.sql` (546.59 MB)
- `complete_schema_and_data_10121005.sql` (547.56 MB)

## 解決方法

### 方法1: git filter-repo を使用（推奨）

1. **バックアップを作成**（重要！）
   ```bash
   cd /Users/kenjiyano/Documents/Sciometa/vsc/SciometaPOS/receipt-scanner
   git clone --mirror . ../receipt-scanner-backup
   ```

2. **Git履歴から大きなSQLファイルを削除**
   ```bash
   git filter-repo --path complete_schema_and_data_09120733.sql \
                   --path complete_schema_and_data_09121520.sql \
                   --path complete_schema_and_data_10121005.sql \
                   --invert-paths --force
   ```

3. **リモートを再設定**（filter-repoはoriginを削除します）
   ```bash
   git remote add origin https://github.com/kenjisciometa/receipt-scanner.git
   ```

4. **強制プッシュ**（⚠️ 注意：履歴が書き換えられるため、他の人が作業している場合は調整が必要）
   ```bash
   git push origin main --force
   ```

### 方法2: git filter-branch を使用（git filter-repoが使えない場合）

```bash
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch complete_schema_and_data_09120733.sql complete_schema_and_data_09121520.sql complete_schema_and_data_10121005.sql" \
  --prune-empty --tag-name-filter cat -- --all

# リモートに強制プッシュ
git push origin main --force
```

### 方法3: BFG Repo-Cleaner を使用

1. BFGをダウンロード: https://rtyley.github.io/bfg-repo-cleaner/
2. 実行:
   ```bash
   java -jar bfg.jar --delete-files complete_schema_and_data_*.sql
   git reflog expire --expire=now --all && git gc --prune=now --aggressive
   git push origin main --force
   ```

## 注意事項

⚠️ **重要**: これらの操作はGit履歴を書き換えます。以下の点に注意してください：

1. **必ずバックアップを作成**してから実行してください
2. 他の開発者と共有しているリポジトリの場合、全員に通知が必要です
3. 履歴が書き換えられるため、他の開発者は新しい履歴を取得する必要があります：
   ```bash
   git fetch origin
   git reset --hard origin/main
   ```

## 今後の対策

`.gitignore`ファイルに以下を追加済みです：
```
complete_schema_and_data_*.sql
*.sql
```

これにより、今後このような大きなSQLファイルが誤ってコミットされることを防ぎます。

