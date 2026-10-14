# IPカメラ → NAS 録画 セットアップ作業ログ

新カメラ1台を UGREEN NAS 上の Frigate(Docker) で常時録画できるようにした作業の経過記録。
手順の完成版は [ip-camera-nas-recording-setup.md](./ip-camera-nas-recording-setup.md) を参照。
このファイルは「何が起きて、どう判断し、何が未解決か」を他セッションが把握するための引き継ぎ用。

**作業日**: 2026-09-21
**作業者**: Claude Code セッション（Mac から実施）

---

## 最終状態（結論）

**録画は稼働中。** 2026-09-21 09:06 時点で正常継続を確認。

| 項目 | 値 |
|---|---|
| Frigate コンテナ | `Up (healthy)`、`restart: unless-stopped`（NAS再起動後も自動復帰） |
| 稼働開始 | 2026-09-21 08:44 頃（NASローカル時刻） |
| 録画総量（09:06時点） | 162MB / 136セグメント（10秒/本） |
| 接続品質 | excellent、reconnects=0、stalls=0、skipped_fps=0 |
| camera_fps | 5.0（expected 5） |

閲覧: `http://192.168.1.254:5000` の Recordings/History タブでタイムライン再生。

---

## 確定した構成値

### カメラ（新規1台）
| 項目 | 値 |
|---|---|
| メーカー系統 | XiongMai(XM)系。RTSPバナー `H264DVR 1.0`、プラグイン配布元 `xmsecu.com` |
| MAC | `00:12:34:6c:31:fe` |
| IP | **`192.168.1.20`**（出荷時 `192.168.1.10` から変更） |
| ゲートウェイ | `192.168.1.99`（出荷時 `192.168.1.1` から修正） |
| 映像 | H.265(HEVC) / 2560×1440 / 25fps / 音声 PCMA(G.711) |
| 認証 | admin / **パスワード空**（未設定のまま。後述） |
| ポート | RTSP 554 / ONVIF 8899 / XM DVRIP 34567 / HTTP 80 |
| RTSP URL | `rtsp://admin:@192.168.1.20:554/user=admin&password=&channel=1&stream=0.sdp` |

### NAS
| 項目 | 値 |
|---|---|
| 機種 | UGREEN NASync DXP4800 Plus（Debian 12 / Docker 26.1.0 / Compose v2.26.1） |
| IP | `192.168.1.254` |
| 管理UI | `http://192.168.1.254:9999` |
| SSH | ポート22、パスワード認証。ユーザーは admin/users グループ（docker は sudo 経由） |
| ストレージ | `/volume1` = 60TB（56TB空き、ext4） |
| Frigate配置 | `/volume1/docker/frigate/`（config.yml, docker-compose.yml, storage/） |
| 録画保存先 | `/volume1/docker/frigate/storage/recordings/日付/時/cam01/*.mp4` |

### Mac 側ネットワーク
USB有線アダプタ AX88179B（インターフェース `en8`）で `192.168.1.0/24` に接続。
Mac自身のIP `192.168.1.207`。デフォルトルートは en8 経由。

---

## 作業の経過（時系列）

### 1. ネットワーク/カメラ発見
- Mac の有線接続を確認 → en8(AX88179B) で 192.168.1.0/24 に接続、GW 192.168.1.99。
- `fping` スイープ + `nmap` で、セグメント上に **Hikvision(`e8:b7:23`)系カメラ24台**が既存。
  → いずれも**録画されていない**（映像を流しているだけ）ことが後に判明。
- 新カメラは XM系で、RTSP + ffmpeg でライブ映像確認に成功（オフィス/ラボが映る）。

### 2. IP衝突の発見と解消
- 新カメラの出荷時IPが `192.168.1.10`。だが `.10` には既存の別XMカメラ(`e8:9c:25:6d:ef:cc`)も存在。
  → **同一IPを2台が奪い合う衝突**。ARPを叩くたびにMACが揺れる状態だった。
- 旧カメラ(`e8:9c:25`)は未使用と判明。動かすのは新カメラのみと決定。
- XM系はブラウザUI(Chrome/Safari)非対応、専用アプリ(VMS)も公証なしで非推奨。
  → **XM DVRIP プロトコル(34567)を Mac から直接叩いて**設定変更する方針に。
- MAC照合ガード付きスクリプトで、**新カメラ(`00:12:34`)を掴んだ時だけ**書き込み。
  IP を `.20`、GW を `.99` に変更 → 再起動 → `.20` で映像確認成功、`.10` の衝突解消。

### 3. カメラの時刻同期・パスワード
- 時刻が約1年ずれていた(`2025-08-23`)→ DVRIP `OPTimeSetting` で現在時刻に同期成功。
- **パスワード変更(admin→admin)は未完了**。DVRIP の msgid がファーム世代で異なり、
  1520/1522/1488 いずれも Ret 106/512 で成立せず。閉じたLAN前提で空のまま運用継続と判断。

### 4. 録画先の決定
- 当初 NAS 純正の監視アプリを想定 → **UGREEN にカメラアプリ無し**（App Center未確認だが本体には無し）。
- 既存24台も録画していないため、**録画基盤をゼロから構築**することに。
- NAS で Docker が使える（SSH open, docker 26.1.0）→ **道: NAS上のDockerでFrigate**を選択。
- 録画方式は「常時録画のみ（AI検知なし）」をユーザーが選択。

### 5. Frigate 構築
- SSH接続: `expect` はプロンプト取りこぼしでハング多発 → **SSH_ASKPASS方式**に切替えて安定化。
- ファイル転送: `scp` が UGREEN の sftp で失敗（`remote mkdir ... No such file`）
  → `ssh "cat > /remote/path" < localfile` で流し込み。
- docker は sudo 必須（admin グループだが docker グループ外）→ `echo pw | sudo -S`。
  `sudo cd` 不可 → `sudo sh -c 'cd ... && ...'`。
- **config バリデーションで2回ハマった**:
  1. `stable` タグは 0.16系。0.14形式の config が弾かれた。
  2. config を `:ro` マウントすると `unable to migrate` エラー → `:ro` を外す。
  → `record.retain: {days:14, mode:all}` + version `0.16-0` + 非roマウントで解決。
- 再作成後、API で `cam01` 読み込み・`connection_quality:excellent` を確認、
  録画ファイル(10秒mp4)の連続生成を確認。

### 6. 録画の実物検証
- Web UI にラグあり。ただし録画はストリームコピーのため品質無関係と説明。
- セグメント連続性（10秒刻み欠番なし）+ 統計（reconnect/stall=0）+ ffprobe（200/200フレーム）で
  **途切れなし**を確認。
- ダウンロードした mp4 が QuickTime で「映像なし」に見えた
  → 原因は HEVC タグが **`hev1`**（QuickTime非対応）。`hvc1` に再ミュート(`-c copy -tag:v hvc1`)で解決。
  VLC / Web UI なら hev1 のままでも再生可。

---

## 未解決 / 今後の課題

1. **カメラのパスワードが空**。閉じたLANなので緊急性低。設定するなら XMEye(スマホGUI)が確実。
   設定後は Frigate config.yml の RTSP URL を `admin:<新PW>@` に更新すること。
2. **保持期間14日**。56TBあるので延長可（config の `days` 変更 → force-recreate）。
3. **既存Hikvision 24台は未録画**。将来 Frigate に追加可能（config の cameras に追記）。
   ただし Hikvision の RTSP URL 形式は XM と異なる（`/Streaming/Channels/101` 等）。
4. **AI動体検知は無効**。人/車検知やイベント検索が欲しくなったら detect を有効化。
   ただし CPU検知は負荷高（ログに warning あり）、GPU/Coral 推奨。

---

## 現状確認コマンド（他セッション向け）

NAS認証情報は git 管理外の安全な場所に保管（このリポジトリには置かない）。
SSH は SSH_ASKPASS 方式（[手順ドキュメント](./ip-camera-nas-recording-setup.md)参照）。

```bash
# コンテナ稼働 & 現在時刻
sudo docker ps --filter name=frigate --format '{{.Status}}'
date '+%Y-%m-%d %H:%M:%S'

# 最新セグメント（タイムスタンプが現在時刻に追随していれば録画中）
sudo ls -lt /volume1/docker/frigate/storage/recordings/*/*/cam01/*.mp4 | head -5

# 途切れ統計（reconnect/stall が 0 なら健全）
sudo docker exec frigate curl -s http://127.0.0.1:5000/api/stats \
  | grep -oE '"cam01":\{[^}]*' | tr ',' '\n' | grep -iE 'reconnect|stall|camera_fps|quality'

# 総量・本数
sudo du -sh /volume1/docker/frigate/storage/recordings
sudo find /volume1/docker/frigate/storage/recordings -name '*.mp4' | wc -l
```

閲覧・エクスポート: `http://192.168.1.254:5000`
