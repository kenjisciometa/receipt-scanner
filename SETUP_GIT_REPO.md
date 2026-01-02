# receipt-scannerを独立したGitリポジトリにする手順

## 問題
現在、Gitリポジトリのルートが親ディレクトリ（`SciometaPOS`）にあるため、親ディレクトリ全体がGitリポジトリに含まれています。
`receipt-scanner`だけを独立したGitリポジトリにする必要があります。

## 解決手順

### 1. receipt-scannerディレクトリ内に新しいGitリポジトリを初期化

```bash
cd /Users/kenjiyano/Documents/Sciometa/vsc/SciometaPOS/receipt-scanner
git init
```

### 2. リモートリポジトリを設定

```bash
git remote add origin https://github.com/kenjisciometa/receipt-scanner.git
```

### 3. すべてのファイルをステージング

```bash
git add .
```

### 4. 初回コミット

```bash
git commit -m "Initial commit: receipt-scanner as independent repository"
```

### 5. メインブランチを設定（必要に応じて）

```bash
git branch -M main
```

### 6. リモートにプッシュ

```bash
git push -u origin main
```

## 注意事項

- 親ディレクトリの`.gitignore`に`receipt-scanner/`を追加済みです
- これにより、親ディレクトリのGitリポジトリから`receipt-scanner`が除外されます
- `receipt-scanner`は独立したGitリポジトリとして管理されます

## 既存の履歴について

もし親ディレクトリのGitリポジトリに既に`receipt-scanner`の履歴がある場合、以下のコマンドで履歴をコピーできます：

```bash
cd /Users/kenjiyano/Documents/Sciometa/vsc/SciometaPOS/receipt-scanner
git init
git remote add origin https://github.com/kenjisciometa/receipt-scanner.git

# 親ディレクトリのGitリポジトリからreceipt-scannerの履歴を取得
cd /Users/kenjiyano/Documents/Sciometa/vsc/SciometaPOS
git subtree push --prefix=receipt-scanner origin main
```

ただし、大きなSQLファイルが履歴に含まれている場合は、先に履歴から削除する必要があります（`REMOVE_LARGE_FILES.md`を参照）。

