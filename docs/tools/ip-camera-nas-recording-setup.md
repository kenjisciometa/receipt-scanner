# IPカメラ → NAS 常時録画セットアップ手順

XiongMai(XM)系 IPカメラを、UGREEN NAS 上の Docker(Frigate) で常時録画する手順。
2026-09-21 に実施した作業の再現用ドキュメント。

> **認証情報について**: NAS のユーザー名・パスワード、カメラのパスワード等はこのファイルには記載しない。
> git 管理下のため。認証情報は別途安全な場所（パスワードマネージャ等）で管理すること。

---

## 構成概要

| 要素 | 値 |
|---|---|
| カメラ | XiongMai系 IPカメラ (H.265 / 2560×1440 / 25fps / 音声 PCMA) |
| カメラ IP | `192.168.1.20`（出荷時は `192.168.1.10`。衝突回避のため変更） |
| カメラ プロトコル | RTSP(554), ONVIF(8899), XM DVRIP(34567) |
| NAS | UGREEN NASync DXP4800 Plus (Debian 12, Docker 26.1.0) |
| NAS IP / 管理UI | `192.168.1.254` / `http://192.168.1.254:9999` |
| NAS SSH | ポート22, パスワード認証。ユーザーは admin グループ（docker は sudo 経由） |
| 録画ソフト | Frigate (`ghcr.io/blakeblackshear/frigate:stable` = 0.16系) |
| 録画保存先 | `/volume1/docker/frigate/storage`（/volume1 は 60TB / 56TB空き） |
| Frigate Web UI | `http://192.168.1.254:5000` |

ネットワーク: Mac は USB有線アダプタ(AX88179B, en8)経由で `192.168.1.0/24` に接続。
デフォルトゲートウェイ `192.168.1.99`。

---

## 前提ツール（Mac側）

```bash
brew install ffmpeg     # RTSP映像の確認・スナップショット取得
# VLC も可（brew install --cask vlc）
```

---

## 手順1: カメラの発見と映像確認

### セグメント上のカメラを探す
```bash
# ARPスイープでホスト洗い出し
fping -a -q -g 192.168.1.0/24
arp -an | grep en8

# カメラ判定（RTSP/HTTP/ONVIFポート）
nmap -Pn -n --open -p 80,554,8000,8899,34567 <IP>
```
XM系の特徴: RTSP バナー `Server: H264DVR 1.0`、プラグイン配布元 `xmsecu.com`。

### RTSP URL 形式（XM系）
```
rtsp://admin:@<IP>:554/user=admin&password=&channel=1&stream=0.sdp   # メイン(高画質)
rtsp://admin:@<IP>:554/user=admin&password=&channel=1&stream=1.sdp   # サブ(低画質)
```

### 映像スナップショット取得（動作確認）
```bash
ffmpeg -nostdin -rtsp_transport tcp \
  -i 'rtsp://admin:@192.168.1.20:554/user=admin&password=&channel=1&stream=0.sdp' \
  -frames:v 1 -q:v 2 -update 1 -y snap.png
```

### VLC で見る
「ファイル → ネットワークを開く」に上記 RTSP URL を貼る。

---

## 手順2: カメラの IP 変更（XM DVRIP プロトコル直叩き）

XM系カメラのブラウザUIは Mac の Chrome/Safari では動かない（プラグイン依存）。
専用アプリ(XMEye/VMS)も難あり。そこで **34567番の DVRIP プロトコルを直接叩いて**設定変更する。

> 出荷時 IP が全機 `192.168.1.10` のため、複数台あると IP 衝突する。
> 変更対象を MAC アドレスで確定してから書き込むこと（誤操作防止）。

### DVRIP の要点
- ログイン: msgid `1000`、パスワードは XM独自ハッシュ（下記 `xm_hash`）
- ネットワーク設定 読み取り: msgid `1042`, `Name: "NetWork.NetCommon"`
- ネットワーク設定 書き込み: msgid `1040`
- 再起動: msgid `1450`, `OPMachine: {Action: Reboot}`
- 時刻設定: msgid `1450`, `OPTimeSetting: "YYYY-MM-DD HH:MM:SS"`
- IP等は LE hex 表記（例 192.168.1.10 → `0x0A01A8C0`）

XM独自パスワードハッシュ:
```python
import hashlib
def xm_hash(pw):
    m = hashlib.md5(pw.encode()).digest(); o = ""
    for i in range(8):
        n = (m[2*i] + m[2*i+1]) % 62
        o += chr(ord('0')+n) if n<10 else chr(ord('A')+n-10) if n<36 else chr(ord('a')+n-36)
    return o
```

実装スクリプトは作業時の scratchpad に `xm_read.py` / `xm_setip.py` として作成。
（MAC照合ガード付き: 期待MACでなければ書き込まない。新カメラを掴むまでリトライ）

### 変更内容（今回）
| 項目 | 変更前 | 変更後 |
|---|---|---|
| IP | 192.168.1.10 | 192.168.1.20 |
| ゲートウェイ | 192.168.1.1 | 192.168.1.99 |
| サブネット | 255.255.255.0 | 変更なし |

書き込み後カメラは再起動し、旧IPから応答しなくなる（正常）。`.20` で ping/RTSP 確認。

### 時刻同期
`OPTimeSetting`(msgid 1450) で現在時刻を設定。出荷時は日時がずれていることが多い。

> **未完了メモ**: パスワード変更(admin→admin)は DVRIP の msgid が
> ファーム世代で異なり、本作業では成立せず（Ret 106/512）。
> パスワードは空のまま運用中。変更する場合は XMEye(スマホアプリ)のGUIが確実。
> 変更したら Frigate config.yml の RTSP URL も更新すること。

---

## 手順3: NAS への SSH 接続（Mac から）

UGREEN NAS は Debian ベース。SSH パスワード認証が有効。
`expect` はプロンプト取りこぼしでハングしやすいので **SSH_ASKPASS 方式**が安定。

```bash
# パスワードを返すヘルパー（認証情報ファイルから読む。ファイルは git 管理外に置くこと）
cat > askpass.sh <<'EOF'
#!/bin/bash
cat /path/to/secure/nas_password.txt   # git管理外の安全な場所
EOF
chmod +x askpass.sh

# コマンド実行（stdin切断が必須。setsidはmacOSに無い）
SSH_ASKPASS=./askpass.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0 \
ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password \
    -o NumberOfPasswordPrompts=1 <user>@192.168.1.254 "コマンド" < /dev/null
```

### 注意点
- `docker` は sudo が必要（ユーザーは admin グループだが docker グループ外）。
  sudo はパスワード要求 → `echo '<pass>' | sudo -S -p '' <cmd>`
- `sudo cd ...` は不可 → `sudo sh -c 'cd ... && ...'` でラップ
- `scp` は UGREEN の sftp で `remote mkdir ... No such file` エラーになる
  → `ssh <host> "cat > /remote/path" < localfile` で流し込む

---

## 手順4: Frigate 構築

### ディレクトリ作成
```bash
mkdir -p /volume1/docker/frigate/storage
```

### config.yml（常時録画のみ・AI検知なし・Frigate 0.16系）
```yaml
mqtt:
  enabled: false

detectors:
  cpu1:
    type: cpu

cameras:
  cam01:
    enabled: true
    ffmpeg:
      inputs:
        - path: "rtsp://admin:@192.168.1.20:554/user=admin&password=&channel=1&stream=0.sdp"
          input_args: preset-rtsp-generic
          roles:
            - record
            - detect
    detect:
      enabled: false
    record:
      enabled: true
      retain:
        days: 14
        mode: all

version: 0.16-0
```

> **重要（ハマりどころ）**:
> - `stable` タグは 0.16 系。0.14 形式の config（`record.retain` の旧書式や
>   `continuous:` 併記）はバリデーションエラーになる。上記の `retain: {days, mode}` 形式が正。
> - config を `:ro`（読み取り専用）でマウントすると
>   `Config file is read-only, unable to migrate` エラー。**:ro を付けない**こと。

### docker-compose.yml
```yaml
services:
  frigate:
    container_name: frigate
    image: ghcr.io/blakeblackshear/frigate:stable
    restart: unless-stopped
    shm_size: "128mb"
    volumes:
      - /volume1/docker/frigate/config.yml:/config/config.yml
      - /volume1/docker/frigate/storage:/media/frigate
      - type: tmpfs
        target: /tmp/cache
        tmpfs:
          size: 1000000000
    ports:
      - "5000:5000"     # Web UI
      - "8554:8554"     # RTSP restream
      - "8555:8555/tcp"
      - "8555:8555/udp"
```

### 起動
```bash
sudo sh -c 'cd /volume1/docker/frigate && docker compose up -d'
# 設定変更後の再作成:
sudo sh -c 'cd /volume1/docker/frigate && docker compose up -d --force-recreate'
```

---

## 手順5: 動作確認

```bash
# コンテナ状態
sudo docker ps --filter name=frigate --format '{{.Names}} | {{.Status}}'   # → Up ... (healthy)

# 設定エラーの有無（何も出なければOK）
sudo docker logs frigate 2>&1 | grep -iE 'Validation Error|Key .*:|read-only'

# カメラ読み込み・接続品質
sudo docker exec frigate curl -s http://127.0.0.1:5000/api/stats | grep -oE '"cameras":\{[^}]*'
#  → camera_fps, connection_quality:"excellent" などが見えればOK

# 録画ファイル生成（10秒セグメントの .mp4 が連続生成される）
sudo find /volume1/docker/frigate/storage/recordings -type f -name '*.mp4' | head
sudo du -sh /volume1/docker/frigate/storage/recordings
```

### 閲覧・巻き戻し
ブラウザで **`http://192.168.1.254:5000`** → 「Recordings / History」タブでタイムライン再生。

---

## 運用メモ

- **自動起動**: `restart: unless-stopped` により NAS 再起動後も自動復帰。
- **保持期間の変更**: config.yml の `days: 14` を変更 → `docker compose up -d --force-recreate`。
  56TB あるので数ヶ月保持も可能（H.265/QHD で約4〜8GB/時）。
- **カメラ追加**（既存機を足す等）: config.yml の `cameras:` に同形式で追記して再作成。
- **カメラのパスワード**: 空のまま。設定したら config.yml の RTSP URL の `admin:@` 部分を
  `admin:<新PW>@` に更新すること。

---

## 録画の連続性を検証する

「Web UI にラグがある」＝「録画も途切れている」ではない。
Web UI(`:5000`) のラグは go2rtc → ブラウザの中継/再エンコード経路で生じる表示上の遅延。
録画は RTSP を**再エンコードせずコピー**してディスクに書くため、Web UI が重くても録画品質は無関係。

### ① セグメントの連続性（NAS上・ファイル名で判定）
ファイル名は録画開始の「分.秒」。10秒刻みで欠番が無ければ連続録画できている。
```bash
sudo ls -la /volume1/docker/frigate/storage/recordings/*/*/cam01/ | tail -20
# 44.26 → 44.36 → 44.46 → 44.56 → 45.06 ... と10秒刻みで欠けが無ければOK
# サイズが極端に小さいファイルが無いことも確認（壊れセグメントの検出）
```

### ② 接続統計（API・途切れの痕跡）
```bash
sudo docker exec frigate curl -s http://127.0.0.1:5000/api/stats \
  | grep -oE '"cam01":\{[^}]*' | tr ',' '\n' | grep -iE 'reconnect|stall|fps|quality'
```
以下なら途切れ無し:
- `reconnects_last_hour: 0`（ストリーム切断なし）
- `stalls_last_hour: 0`（停止なし）
- `skipped_fps: 0.0`（フレームスキップなし）
- `connection_quality: "excellent"`

### ③ 実ファイルのフレーム完全性（Mac に落として ffprobe）
```bash
# nb_frames が fps×尺 と一致すればフレーム落ちなし
ffprobe -v error -count_frames -select_streams v:0 \
  -show_entries stream=nb_read_frames -of default=noprint_wrappers=1 sample.mp4
# 例: 20fps × 10秒 = 200 → nb_read_frames=200 ならOK
```

---

## 録画ファイルをダウンロードする

### 方法A: Frigate Web UI から（推奨・最も簡単）
`http://192.168.1.254:5000` → タイムラインで範囲選択 → **Export** で指定区間を1本のmp4に書き出し。
SSH 不要。ブラウザ側デコードなので後述の hev1 問題も起きない。

### 方法B: NAS のファイル共有（SMB）
録画は `/volume1/docker/frigate/storage/recordings/日付/時/cam01/` に10秒mp4で蓄積。
`smb://192.168.1.254` からアクセス。ただしフォルダ所有者が root のため、
共有に見せるには権限調整が要る場合あり。

### 方法C: SSH で特定ファイルを取得（cat 経由）
scp は UGREEN で失敗するため cat で吸い出す:
```bash
LATEST=$(ssh ... "sudo ls -t /volume1/docker/frigate/storage/recordings/*/*/cam01/*.mp4 | head -1")
ssh ... "sudo cat '$LATEST'" < /dev/null > ~/Downloads/sample.mp4
```

---

## ⚠️ 再生できない場合: hev1 → hvc1 タグ問題

**症状**: ダウンロードした mp4 を QuickTime で開くと「映像が含まれていない」/真っ黒/音声のみ。

**原因**: HEVC(H.265) の MP4 互換タグには `hvc1` と `hev1` の2種があり、
**QuickTime Player は `hev1` を再生できない**（`hvc1` のみ対応）。
Frigate はストリームコピー録画するため、カメラ由来の `hev1` タグがそのまま付く。
映像データ自体は正常（VLC なら hev1 でも再生可）。

**確認**:
```bash
ffprobe -v error -select_streams v:0 -show_entries stream=codec_tag_string \
  -of default=noprint_wrappers=1 sample.mp4
# codec_tag_string=hev1 なら QuickTime で再生不可
```

**対処**（再エンコードなし・一瞬・画質劣化ゼロ）:
```bash
ffmpeg -i sample.mp4 -c copy -tag:v hvc1 -movflags +faststart -y sample_playable.mp4
# → codec_tag_string=hvc1 になり QuickTime で再生可能
```

**まとめ**:
- **VLC** で見る → hev1 のままでOK、変換不要
- **QuickTime** で見る → 上記で `hvc1` に書き換え
- **Frigate Web UI / Export** → ブラウザデコードのため問題なし（普段はこれが最も楽）
