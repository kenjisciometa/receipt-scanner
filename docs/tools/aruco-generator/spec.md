# ArUcoマーカー ジェネレーター 定義書

## 概要

ArUcoマーカーを指定した番号から連番でA4用紙にレイアウトし、PDFとして出力するPythonスクリプト。

## 要件

### 出力仕様

| 項目 | 値 |
|------|-----|
| 用紙サイズ | A4 (210mm x 297mm) |
| マーカーサイズ | 25mm x 25mm |
| ArUco辞書 | `DICT_4X4_250`（デフォルト、オプション変更可） |
| 出力形式 | PDF |

### マーカー配置

- マーカーは25mm四方のサイズで等間隔に配置
- マーカー間にはラベル（マーカーID）を表示
- 余白を確保し、印刷時に切れないようにする
- 1ページに収まらない場合は複数ページに分割

### コマンドライン引数

| 引数 | 必須 | 説明 | デフォルト |
|------|------|------|-----------|
| `--start` | Yes | 開始マーカーID | - |
| `--count` | Yes | 生成するマーカー数 | - |
| `--output` | No | 出力PDFファイル名 | `aruco_markers.pdf` |
| `--dict` | No | ArUco辞書タイプ | `DICT_4X4_250` |
| `--size` | No | マーカーサイズ(mm) | `25` |

### 使用例

```bash
# ID 0から20枚のマーカーを生成
python generate_aruco.py --start 0 --count 20

# ID 100から50枚、出力ファイル指定
python generate_aruco.py --start 100 --count 50 --output markers_100-149.pdf

# 6x6辞書で生成
python generate_aruco.py --start 0 --count 10 --dict DICT_6X6_250
```

## 依存パッケージ

```
opencv-python
opencv-contrib-python
reportlab
numpy
```

### インストール

```bash
pip install opencv-python opencv-contrib-python reportlab numpy
```

## ファイル構成

```
docs/aruco-generator/
├── spec.md              # 本定義書
├── generate_aruco.py    # メインスクリプト
└── requirements.txt     # 依存パッケージ
```

## レイアウト詳細

### A4ページ上の配置計算

- A4: 210mm x 297mm
- 上下左右マージン: 15mm
- 印刷可能領域: 180mm x 267mm
- マーカーサイズ: 25mm
- マーカー間隔（ラベル含む）: 約10mm
- 列数: `floor(180 / (25 + 10))` = 5列
- 行数: `floor(267 / (25 + 10))` = 7行
- 1ページあたり最大: 35マーカー

### ラベル

各マーカーの下にマーカーIDをテキストで表示（例: `ID: 042`）。
