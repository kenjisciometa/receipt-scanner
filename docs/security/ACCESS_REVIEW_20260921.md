# アクセス権見直し手順書（人事異動対応）

- **作成日**: 2026-09-21
- **最終更新**: 2026-09-21（§B-6 リポジトリ移行を追加。§0 / §B-2 / §B-4 / §C / §D を改訂）
- **対象サーバー**: `external01` (Ubuntu 22.04.5 LTS / 10.10.10.1)
- **目的**: 異動に伴い `keisuke@sciometa.com` の外部アクセスを遮断する
- **方針**: 最小限 — 該当者の鍵・アカウント・認証情報のみ失効。本番サービスは停止しない
- **調査範囲**: 認証ログ 2026-08-23 〜 2026-09-21（約30日、ローテート分を含む全件）

> **この文書の読み方**
> 「§A 調査結果」は実施済みの現状把握です。
> 「§B 作業手順」が実際に行う作業で、**影響の小さい順に並べています**。
> 作業ごとに所要時間・影響範囲・ロールバック手順を記載しています。

---

## §0 サマリ（先に読む）

### 遮断すべき経路は 5 つ

| # | 経路 | 対象者の保持状況 | 優先度 | 状況 |
|---|---|---|---|---|
| 1 | SSH 公開鍵（`external01` アカウント） | **保持・現役利用中** | **最優先** | 完了 |
| 2 | GitHub リポジトリ権限（うち剥奪で足りるのは4件） | 保持 | 高 | 未着手 |
| 3 | FortiGate 管理者アカウント | 要確認 | 高 | 完了 |
| 4 | IPsec VPN の PSK | 要確認 | 中（条件付き） | 未着手 |
| 5 | **本人所有リポジトリ 4 件（権限剥奪では対処不能）** | **本人がオーナー** | **高** | §B-6・第1段階完了 |

> 経路 1（SSH）と経路 3（FortiGate）は対応済みです。
> 残りは GitHub 側（経路 2・4・5）です。

### 最重要の注意点

**本番稼働中の 4 リポジトリが対象者の個人アカウント配下にあります。**
`TunaInanamu/*` の 4 件は**本人がオーナー**のため、Collaborator 権限の剥奪では
遮断できません。オーナー権限はリポジトリの削除・公開範囲変更まで及びます。
**§B-6 のリポジトリ移行が必要です**（当初「3件」と把握していましたが、
調査の結果 `scioweb` を含む **4 件**であることが判明しました）。


**`external01` は共有アカウントです。** keisuke 氏・akihiro 氏・CI が同一の
`/home/external01/.ssh/authorized_keys` を使っており、このアカウントは
`sudo` `docker` `adm` `lxd` グループに所属しています。
**この鍵で入れる = 実質 root 相当**です。

**keisuke 鍵は 2026-09-17 まで使われていました。** 休眠鍵ではありません。
削除すると本人の作業が即座に止まるため、**事前周知を行ってください**。

---

## §A 調査結果

### A-1. サーバー基本情報

| 項目 | 内容 |
|---|---|
| ホスト名 | `external01` |
| OS | Ubuntu 22.04.5 LTS (Linux 5.15.0-174-generic) |
| 稼働期間 | 161日連続（最終起動 2026-04-12） |
| LAN IP | `10.10.10.1/24` |
| デフォルト GW | `10.10.10.254`（= FortiGate） |
| グローバル IP | `194.157.26.62`（FortiGate） |
| Docker | 38 コンテナ稼働中 |

### A-2. SSH 設定（`/etc/ssh/sshd_config`）

現状の設定は堅牢です。**変更不要**。

| 設定 | 値 | 評価 |
|---|---|---|
| `Port` | `2200` | 非標準ポート |
| `PasswordAuthentication` | `no` | 良好 |
| `PubkeyAuthentication` | `yes` | — |
| `PermitEmptyPasswords` | `no` | 良好 |
| `MaxAuthTries` | `3` | 良好 |
| `AllowTcpForwarding` | `no`（`external01` のみ `yes`） | — |
| `LogLevel` | `VERBOSe` | 動作はするが綴り誤り。いずれ修正推奨 |

> `AllowUsers` / `AllowGroups` による**ユーザー制限は未設定**です。
> 全アカウントが SSH ログイン可能な状態です。

### A-3. SSH 鍵台帳（確定版）

`/home/external01/.ssh/authorized_keys` — **システム内で唯一の authorized_keys**

| # | コメント | フィンガープリント | 認証成功 | 最終使用 | 接続元 | 判定 |
|---|---|---|---|---|---|---|
| 1 | `keisuke@sciometa.com` | `SHA256:e42jiKbCVQBYoBRYuDZ2n1xCG08tWJNmxEmy6fqqzXA` | 62 | **2026-09-17** | `10.10.10.254` | **削除対象** |
| 2 | `github-actions@sciometa` | `SHA256:7fZHzy6Q/vOrn0INJV5m7uapSAmM7vdlH6xsEdv2Px8` | **0** | なし | — | 未使用・整理候補 |
| 3 | `github-actions-scioweb` | `SHA256:JewGA4ynCN0NLHdnZI78pFgKWl216+giFl3DDAUHhn4` | 2 | 2026-08-24 | `10.10.10.254` | 低頻度・保持 |
| 4 | `bos-deploy-ci` | `SHA256:rhyInNV054Spy4BtdUgzJwB44b5cjLrgv0aoew6DAF0` | 83 | 2026-09-18 | `192.168.2.51` | 現役・保持 |
| 5 | `bos-deploy-ci`（**#4 と同一鍵の重複登録**） | `SHA256:rhyInNV054Spy4BtdUgzJwB44b5cjLrgv0aoew6DAF0` | (同上) | (同上) | (同上) | 重複・整理候補 |
| 6 | `akihiro.fin@gmail.com` | `SHA256:ClVQuM1nwb+/ILK4WikTIfXh0A03nXGAueW0eKsyzCc` | 6 | 2026-09-18 | `10.10.10.254` | 現役・個人Gmail鍵 |

**参考: `deploy` ユーザー側の鍵**（`authorized_keys` には含まれない別管理）

| 用途 | フィンガープリント | 認証成功 | 最終使用 |
|---|---|---|---|
| CI 自動デプロイ | `SHA256:3oQLmwH6JT8MVQkPeWjPz6d2r1QFSeZQ7A91tRmvf3U` | 355 | 2026-09-20 |

### A-4. アカウントと権限

```
external01 (uid=1000)  groups: adm, sudo, lxd, syslog, sciometa, docker, deploy  ← 共有アカウント
deploy     (uid=1001)  groups: docker                                            ← CI 専用
sciometa   (uid=114)   shell: /bin/bash
root       (uid=0)
```

### A-5. ネットワーク経路（4系統）

#### ① FortiGate VIP → nginx (80/443)

公開中 FQDN:

- **本番**: `pos.sciometa.com`, `menu.sciometa.com`, `recipe.sciometa.com`,
  `link.sciometa.com`, `shift.sciometa.com`, `katana-ramen.com`,
  `tokyostreethelsinki.com`, `subscription.sciometa.com`
- **開発**: `dev-pos`, `devdev-pos`, `dev-menu`, `dev-recipe`, `dev-shift`,
  `dev-auth`, `auth`, `scioweb-dev/stage`, `katana.web`

#### ② Tailscale VPN（FortiGate を完全にバイパス）

```
100.108.89.6     external01                          tag:esl-server  ← 本サーバー
100.105.209.92   kenjiyanos-macbook-pro              yano.kenji5454@
100.67.3.69      raspberrypi-1                       yano.kenji5454@
100.114.253.102  raspberrypi                         yano.kenji5454@
100.89.148.122   tokyostreet-to-be-filled-by-o-e-m   yano.kenji5454@（offline）
```

- `ShieldsUp: false` → tailnet 内の全端末から本サーバーへ着信可能
- `RunSSH: false` → Tailscale SSH は無効（通常の sshd 経由のみ）
- **keisuke 氏名義の端末は登録されていない → 本経路は今回の対象外**

> NAT 越えで外向きに接続を確立するため、**FortiGate のインバウンドルールでは
> 止められません**。tailnet の管理は Tailscale 管理コンソールで行います。

#### ③ SSH（ポート 2200）

`0.0.0.0:2200` で全インターフェース待受。外部到達性は FortiGate の VIP 設定次第。

#### ④ IPsec VPN（GitHub Actions → FortiGate）

GitHub Actions ランナーが `secrets.VPN_PSK` で `194.157.26.62` へ IKEv2 接続。
詳細は §B-4 を参照。

### A-6. ローカルファイアウォールが実質無防備

| 項目 | 状態 |
|---|---|
| UFW | **未インストール** |
| firewalld | inactive |
| iptables (filter) | **ルールなし**（Docker 生成分を除く） |
| nftables | ルールなし |

**FortiGate が唯一の防御層です。** 以下が `0.0.0.0` で待受中:

| ポート | サービス | 危険度 |
|---|---|---|
| `5306` | **MySQL** | 🔴 DB 直結 |
| `6380` / `9079` / `8079` | **Redis ×3** | 🔴 通常無認証 |
| `8082` | redis-commander | 🟠 Redis GUI |
| `9091` | Prometheus | 🟠 |
| `9007` | Grafana | 🟠 |
| `19999` | netdata | 🟠 |
| `8089` | grafana-data-api | 🟠 |
| `8888` | nginx-status | 🟡 nginx 側で IP 制限あり |

> **§B-5 で FortiGate 側の到達性を必ず確認してください。**

### A-7. nginx の IP allowlist が場当たり的

`dev-auth.sciometa.com` / `auth.sciometa.com` / `dev-pos.sciometa.com` に
個別の allow リストが存在:

```nginx
allow 10.15.10.0/24;  allow 192.168.1.0/24;
allow 82.141.86.169;  allow 37.33.128.57;
allow 85.76.145.161;  allow 198.185.159.145;
allow 127.0.0.1;      allow 172.16.0.0/12;
allow 10.10.10.254;   allow 194.157.26.62;   # Current IP
```

**問題点:**

- 各IPの帰属が不明（誰の自宅・オフィスか記録なし）→ 異動のたびに棚卸しできない
- `sciometa-pos-dev` は一部 location で `allow all;` により `deny all` を上書き
- 3ファイルに同内容が重複 → 片方だけ直す事故が起きやすい

**推奨**: `/etc/nginx/snippets/office-allowlist.conf` に切り出して
`include` で共有し、各行に帰属コメントを付ける。

---

## §B 作業手順

### 事前準備（全作業共通）

1. **作業前に本人へ周知**
   keisuke 鍵は 2026-09-17 まで使用実績があります。無通告の削除は業務を止めます。

2. **作業ウィンドウの確保**
   §B-4（PSK）は全デプロイを一時停止させます。デプロイが走らない時間帯に実施。

3. **復旧経路の確保**
   作業中に締め出された場合に備え、**Tailscale 経由（`100.108.89.6`）でのアクセスを
   確認しておいてください**。FortiGate をバイパスするため、§B-3 / §B-5 で
   誤って自分を締め出しても復旧できます。

---

### B-1. SSH 鍵の失効 ★最優先

- **所要**: 1 分
- **影響**: 本番サービスへの影響なし。keisuke 氏の SSH のみ不可になる
- **権限**: `external01` 本人で実行可（sudo 不要）
- **実行場所**: `external01` サーバー上

#### 手順

```bash
cd /home/external01/.ssh

# 1. バックアップ（必ず先に）
cp -a authorized_keys authorized_keys.bak.$(date +%Y%m%d-%H%M%S)

# 2. 削除前の確認（6行あるはず）
wc -l authorized_keys
ssh-keygen -lf authorized_keys

# 3. keisuke 鍵を削除
grep -vF 'keisuke@sciometa.com' authorized_keys > authorized_keys.new

# 4. 差分確認（1行だけ減っていること）
diff <(ssh-keygen -lf authorized_keys) <(ssh-keygen -lf authorized_keys.new)

# 5. 適用
mv authorized_keys.new authorized_keys
chmod 600 authorized_keys

# 6. 検証（e42ji... が消えていること）
ssh-keygen -lf authorized_keys
```

> **重要**: この作業では `sshd` の再起動は不要です。
> `authorized_keys` は接続のたびに読み直されます。
> **既存の接続済みセッションは切断されません**（本人が再接続した時点で拒否）。

#### 同時に整理を推奨（任意）

```bash
# #5（bos-deploy-ci の重複）と #2（未使用の github-actions@sciometa）を削除
awk '!seen[$2]++' authorized_keys > authorized_keys.dedup   # 重複鍵を除去
grep -vF 'github-actions@sciometa' authorized_keys.dedup > authorized_keys.new
ssh-keygen -lf authorized_keys.new   # 3行になるはず
mv authorized_keys.new authorized_keys && chmod 600 authorized_keys
rm -f authorized_keys.dedup
```

#### ロールバック

```bash
cp -a /home/external01/.ssh/authorized_keys.bak.<タイムスタンプ> \
      /home/external01/.ssh/authorized_keys
chmod 600 /home/external01/.ssh/authorized_keys
```

#### 確認方法（翌日以降）

```bash
# 削除した鍵での認証試行がないこと
sudo grep 'e42jiKbCVQBYoBRYuDZ2n1xCG08tWJNmxEmy6fqqzXA' /var/log/auth.log
```

---

### B-2. GitHub リポジトリ権限の剥奪 ★推奨

- **所要**: 5 分
- **影響**: 小
- **権限**: 各 GitHub アカウント/Organization の管理者権限

> **§B-4（PSK ローテーション）より先に、こちらを検討してください。**
> GitHub Secrets は**登録後に値を読み出せません**。該当者が Secrets 経由でしか
> VPN にアクセスしていないなら、**リポジトリ権限を外すだけで遮断完了**です。
> PSK ローテーションは不要になります。

> **⚠️ 当初の想定を訂正**
> 本節はもともと 7 リポジトリすべてを「権限剥奪」の対象としていましたが、
> **`TunaInanamu/*` の 4 件は対象者本人がオーナーであり、剥奪できません。**
> API で確認した結果、当社側アカウント `kenjisciometa` の権限は
> `admin: false` / `pull: true` / `push: true`（＝ Collaborator 止まり）でした。
> **本節で対応できるのは `kenjisciometa/*` の 4 件のみ**です。
> `TunaInanamu/*` の 4 件は **§B-6（リポジトリ移行）** で扱います。

#### B-2a. 権限剥奪で対応できるリポジトリ（4件）

`kenjisciometa` 所有のため、Collaborator から外すだけで遮断完了します。

| リポジトリ | Settings URL |
|---|---|
| `kenjisciometa/sciometapos` | `https://github.com/kenjisciometa/sciometapos/settings/access` |
| `kenjisciometa/shift-management-app` | `https://github.com/kenjisciometa/shift-management-app/settings/access` |
| `kenjisciometa/accountant-app` | `https://github.com/kenjisciometa/accountant-app/settings/access` |
| `kenjisciometa/recipe-app` | `https://github.com/kenjisciometa/recipe-app/settings/access` |

#### 手順

1. 各リポジトリの `Settings` → `Collaborators and teams`
2. 該当アカウント（`TunaInanamu`）を **Remove**
3. Organization 所属なら `People` からも削除
4. `Settings` → `Deploy keys` を確認し、心当たりのない鍵がないかチェック

`gh` CLI でも実行できます（要 `admin:org` 相当の権限）:

```bash
for r in sciometapos shift-management-app accountant-app recipe-app; do
  gh api -X DELETE "repos/kenjisciometa/$r/collaborators/TunaInanamu"
done
```

#### B-2b. 権限剥奪では対処できないリポジトリ（4件）

| リポジトリ | 当社の権限 | 対応 |
|---|---|---|
| `TunaInanamu/ReactRestaurantPOS` | `admin: false` | **§B-6** |
| `TunaInanamu/websocket-server` | `admin: false` | **§B-6** |
| `TunaInanamu/subscription-web` | `admin: false` | **§B-6** |
| `TunaInanamu/scioweb` | `admin: false` | **§B-6** |

> `subscription-web` は当初の調査で「所属不明」とされていたものです（§B-4 / §C-7）。
> `TunaInanamu` 配下であることが判明しました。

---

### B-3. FortiGate 管理者アカウントの無効化

- **所要**: 5 分
- **影響**: 小
- **アクセス先**: `https://10.10.10.254`（LAN 内から。ブラウザで開く）

> **注意**: サーバー上から `curl` で叩くのは管理操作の代替になりません。
> セッション管理が絡むため、**ご自身の PC のブラウザから**操作してください。
> WAN 側 `https://194.157.26.62` は、外部管理が有効な場合のみ到達します
> （本来は塞がっているべき設定です）。

#### 手順

1. **System > Administrators**
   - keisuke 氏のアカウントを探す
   - あれば選択 → **Disable**
     （いきなり Delete しない。設定の紐付けが追えなくなるため。
     問題ないことを1〜2週間確認してから削除）
   - 一覧全体を見て、心当たりのないアカウントがないか確認

2. **System > Admin Profiles**
   - `super_admin` 相当のプロファイルが誰に割り当たっているか確認

3. **User & Authentication > User Definition / User Groups**
   - 個別ユーザーの棚卸し。グループから外すだけでアクセスは止まる

4. **VPN > SSL-VPN Settings** → Authentication/Portal Mapping
   - keisuke 氏のユーザー/グループ割当があれば削除

---

### B-4. IPsec VPN の PSK ローテーション（条件付き）

- **所要**: 15 分＋検証
- **影響**: **大** — 作業中すべてのデプロイが失敗する
- **前提**: §B-2 を実施しても**なお必要な場合のみ**

#### 実施要否の判断

| 状況 | 対応 |
|---|---|
| 該当者が PSK 文字列そのものを知っている可能性がある | **ローテーション必須** |
| GitHub Secrets 経由でしか触れていない | **§B-2 のみで十分**。本作業は不要 |

#### PSK が存在する場所

| 場所 | 作業 |
|---|---|
| FortiGate `194.157.26.62` トンネル設定 | GUI で変更 |
| GitHub Secrets `VPN_PSK` × **9 リポジトリ** | 各リポジトリで更新（内訳は下記） |
| **本サーバー** | **作業不要**（strongSwan 未導入・`/etc/ipsec.secrets` 不在） |

> `/opt/sciometa/servers/ipsec-config/ipsec.conf` はテンプレートの控えで、
> PSK 本体は含まれません（`authby=secret` のみ）。サーバー側で触るものはありません。

#### 影響を受けるワークフロー（全 30 ファイル）

| リポジトリ | ワークフロー |
|---|---|
| `kenjisciometa/sciometapos` | `deploy-internal-test.yml`, `deploy-to-production.yml` |
| `kenjisciometa/shift-management-app` | `deploy-dev.yml`, `deploy-stage.yml`, `deploy-internal-test.yml` |
| `kenjisciometa/accountant-app` | `deploy-stage.yml` |
| `kenjisciometa/recipe-app` | `deploy-dev.yml`, `deploy-stage.yml` |
| `TunaInanamu/ReactRestaurantPOS` | `deploy-dev.yml` |
| `TunaInanamu/websocket-server` | `deploy-dev.yml` |
| `TunaInanamu/scioweb` | `deploy-dev.yml`, `deploy-stage.yml` |
| `TunaInanamu/subscription-web` | `deploy-stage.yml`, `audit-fleet.yml` |
| `kenjisciometa/receipt-scanner` | `deploy-dev.yml` |

> **✅ 所属不明だった 2 件は特定済み（2026-09-21）**
> - `prod/subscription-web` → **`TunaInanamu/subscription-web`**
>   （本人所有のため **§B-6 の移行対象**）
> - `dev/receipt-scanner` → **`kenjisciometa/receipt-scanner`**
>   （当社所有・`admin: true`。移行不要）
>
> **§B-6 を実施する場合、`VPN_PSK` の登録先は移行後の新リポジトリになります。**
> 上表のうち `TunaInanamu/*` の 4 件は、移行と PSK 更新を**同時に行うと
> 二度手間を避けられます**。

#### ステップ 0 — 新しい PSK を生成

```bash
# 記号を含む（強度優先）
openssl rand -base64 48

# 英数字のみ（貼り付け事故を避ける・推奨）
openssl rand -hex 32
```

> **記号に注意**: 生成値は FortiGate GUI への貼り付けと、YAML 内での展開
> （`PSK "${{ secrets.VPN_PSK }}"`）の両方を通ります。
> `"` `\` `$` が含まれると事故のもとです。**`-hex` 版を推奨します。**

生成した値は 1Password 等に保管してください。

#### ステップ 1 — GitHub Secrets を先に更新（9リポジトリ全部）

**必ず GitHub を先に。** 理由は下の補足を参照。

各リポジトリで
`Settings` → `Secrets and variables` → `Actions` → `VPN_PSK` → `Update secret`

**当社所有（5件）— そのまま更新可**

```
https://github.com/kenjisciometa/sciometapos/settings/secrets/actions
https://github.com/kenjisciometa/shift-management-app/settings/secrets/actions
https://github.com/kenjisciometa/accountant-app/settings/secrets/actions
https://github.com/kenjisciometa/recipe-app/settings/secrets/actions
https://github.com/kenjisciometa/receipt-scanner/settings/secrets/actions
```

**本人所有（4件）— §B-6 の移行対象**

```
https://github.com/TunaInanamu/ReactRestaurantPOS/settings/secrets/actions
https://github.com/TunaInanamu/websocket-server/settings/secrets/actions
https://github.com/TunaInanamu/subscription-web/settings/secrets/actions
https://github.com/TunaInanamu/scioweb/settings/secrets/actions
```

> **⚠️ 上記4件は Secrets の更新に `admin` 権限が必要ですが、当社は
> `admin: false` です。** 旧リポジトリ側で `VPN_PSK` を更新できない可能性が
> あります。**§B-6 の移行を先に実施し、移行後の新リポジトリへ新 PSK を
> 登録するのが確実です。**

**この時点ではまだ何も壊れません**（FortiGate が旧 PSK のため、
いま走るデプロイは失敗します）。**ステップ2 まで一気に進めてください。**

> **補足: なぜ GitHub が先か**
> GitHub Actions は実行のたびに新しいランナーでトンネルを張り直す
> 使い捨て構成です（`ipsec up` → 処理 → `ipsec down`）。常時接続ではないため、
> 「GitHub 先 → FortiGate 後」ならダウンタイムは**両者が食い違う数分間だけ**です。
> 逆順だと、FortiGate 変更の瞬間から GitHub 更新完了まで全デプロイが確実に失敗します。

#### ステップ 2 — FortiGate 側を変更

`https://10.10.10.254` → **VPN > IPsec Tunnels**
→ `194.157.26.62` 側に対応するトンネル → **Edit**
→ `Authentication` の **Pre-shared Key** を新 PSK に変更 → **OK / Apply**

#### ステップ 3 — 検証

いずれかのリポジトリで `Actions` → 対象ワークフロー → **Run workflow**
（`workflow_dispatch`）を手動実行。

成功時のログ:

- `Start IPsec VPN connection` が `ipsec up fortigate-vpn` でエラーを出さない
- `Verify VPN connection` の `ping` が通る
- `Deploy application` の SSH が成功する

**失敗時の切り分け:**

| ログ | 原因 |
|---|---|
| `no shared key found` / `AUTHENTICATION_FAILED` | PSK 不一致。更新漏れか貼り付けミス |
| `no IKE_SA` / タイムアウト | FortiGate 側でトンネル設定が無効 |
| ping は通るが SSH 失敗 | PSK は成功。別要因（SSH 鍵・ポート） |

> `AUTHENTICATION_FAILED` が出たら、**まず GitHub Secret の貼り付けを疑って
> ください**。前後の空白・改行混入が最も多い原因です。

#### ステップ 4 — 全リポジトリで検証

9 リポジトリすべてで一度ずつデプロイを流してください。
1つでも漏れると、そのリポジトリだけ後日突然失敗します。
§B-6 を実施済みなら、`TunaInanamu/*` ではなく**移行後の新リポジトリ**で検証します。

#### ロールバック

旧 PSK を保管してあれば、FortiGate と GitHub の両方を旧値に戻します
（順序は同じく GitHub → FortiGate）。

---

### B-5. FortiGate ポリシーの棚卸し（重要・別件）

- **所要**: 15 分
- **影響**: 設定変更する場合は大

§A-6 のとおり、**このサーバーにはローカルファイアウォールがありません**。
FortiGate のポリシーが唯一の防御層です。

#### 確認項目

1. **Policy & Objects > Virtual IPs**
   - ポート `2200`（SSH）の VIP があるか
     - ある → 外部 SSH が本当に必要か検討。**不要なら VIP 削除が最も強い対策**
     - 必要 → Firewall Policy で送信元を社内 IP に限定
   - **`5306`(MySQL) / `6380`,`9079`,`8079`(Redis) / `8082`(redis-commander) の
     VIP が存在しないこと**を必ず確認。あれば即削除を検討

2. **Policy & Objects > Firewall Policy**
   - WAN → DMZ 方向のポリシーを一覧
   - Source が `all` / `any` のものを洗い出す
   - 管理系ポート（`9091`, `9007`, `19999`, `8089`）が外部公開されていないか

> **作業前に §事前準備 3 の復旧経路（Tailscale）を必ず確認してください。**
> ポリシー変更で自分を締め出す可能性があります。

---

### B-6. 本人所有リポジトリの移行 ★重要

- **所要**: 第1段階 15 分（完了）/ 第2段階 1〜2 時間
- **影響**: 第1段階は**なし**（読み取りのみ）。第2段階は**大**（本番デプロイに影響）
- **権限**: 移行元は `pull` があれば足りる。移行先は `kenjisciometa` の管理権限

#### 背景

本番稼働中の 4 リポジトリが対象者の個人アカウント `TunaInanamu` 配下にあります。
**本人がオーナーであるため、Collaborator 権限の剥奪では遮断できません。**

| リポジトリ | 本番コンテナ |
|---|---|
| `TunaInanamu/ReactRestaurantPOS` | `restaurant-pos-prod` |
| `TunaInanamu/websocket-server` | `websocket-server-prod` |
| `TunaInanamu/subscription-web` | `subscription-web-subscription-web-1` |
| `TunaInanamu/scioweb` | （要確認） |

#### 方式の選択

| 方式 | 内容 | 採否 |
|---|---|---|
| A | GitHub の Transfer ownership | **不採用** — オーナー（本人）の操作が必須。当社は `admin: false` |
| B | 新リポジトリ作成 + `git push --mirror` | **採用** |

> 方式 B は履歴・全ブランチを保持したまま複製します。
> ただし **Issue / PR / Wiki / Star は引き継がれません**。
> これらが必要なら、事前に退避するか本人へ Transfer を依頼してください。

---

#### 第1段階 — ミラーバックアップ取得 ✅ **2026-09-21 完了**

GitHub への影響は**読み取りのみ**。Collaborator 権限があるうちに確保するのが目的です。

**保存先**: `/Users/kenjiyano/Documents/Sciometa/backup/github-mirror/`

```bash
mkdir -p /Users/kenjiyano/Documents/Sciometa/backup/github-mirror
cd /Users/kenjiyano/Documents/Sciometa/backup/github-mirror
git clone --mirror https://github.com/TunaInanamu/ReactRestaurantPOS.git
git clone --mirror https://github.com/TunaInanamu/websocket-server.git
git clone --mirror https://github.com/TunaInanamu/subscription-web.git
# scioweb は未取得（下記「残作業」参照）
```

**取得結果と検証**

| リポジトリ | コミット | ブランチ | サイズ | fsck | 先端SHA照合 |
|---|---|---|---|---|---|
| `ReactRestaurantPOS.git` | 3,967 | 83 | 210 MB | ✅ | ✅ 83/83 一致 |
| `websocket-server.git` | 235 | 12 | 5.8 MB | ✅ | ✅ 12/12 一致 |
| `subscription-web.git` | 192 | 5 | 1.6 MB | ✅ | ✅ 5/5 一致 |
| **合計** | **4,394** | **100** | **218 MB** | | |

検証は3段階で実施しました。`git fsck` でオブジェクト破損なし（全件終了コード 0）、
ブランチ数が GitHub API の実測値と一致、さらに**全 100 ブランチの先端 SHA を
GitHub と1本ずつ照合して完全一致**。タグは3件とも元から 0 本です。

```bash
# 検証に使用したコマンド
for r in ReactRestaurantPOS websocket-server subscription-web; do
  git -C "$r.git" fsck --no-progress --no-dangling
  gh api "repos/TunaInanamu/$r/branches" --paginate \
    --jq '.[] | "\(.name) \(.commit.sha)"' | sort > /tmp/gh_$r.txt
  git -C "$r.git" for-each-ref --format='%(refname:short) %(objectname)' \
    refs/heads | sort > /tmp/loc_$r.txt
  diff /tmp/gh_$r.txt /tmp/loc_$r.txt && echo "$r: 一致"
done
```

> **⚠️ 第1段階の残作業**
> **`TunaInanamu/scioweb` は未取得です。** 4 件目の存在が判明したのが
> 取得実施後だったためです。同じ手順で取得してください（約 6.9 MB / 3 branches /
> default branch は `stage`）。

> **⚠️ 現状このバックアップはローカル 1 箇所のみです。**
> 恒久的な会社保管とするには `external01` 等の管理下ストレージへ複製してください。
> 現状は「アクセスが生きているうちの緊急退避」という位置づけです。

---

#### ミラー元に関する注意（重要）

**ローカルの作業ディレクトリを `--mirror` の元にしてはいけません。** 以下の2つの理由で
バックアップとして不完全になります。GitHub から新規に clone してください。

1. **ローカルが古い** — 調査時点で `subscription-web` は最終 fetch が
   1 か月以上前（8/11）、`websocket-server` は 11 日前（9/7）でした。
   ローカルを元にすると、その後 GitHub に入ったコミットが欠落します。
2. **削除済みブランチの残骸** — `ReactRestaurantPOS` はローカルに remote 追跡
   ブランチが 138 本ありましたが、GitHub 実在は 83 本。差分 55 本は GitHub 側で
   削除済みの「亡霊ブランチ」です（`prune` 未実施）。ローカル由来だとこれらを
   新リポジトリへ持ち込みます。

> 当初の引き継ぎにあった「ReactRestaurantPOS: 128 branches」は、この汚れた
> ローカル値に由来する誤りでした。**正しい実数は上表のとおりです。**

> **stash は移行対象外です。** `ReactRestaurantPOS` に 3 件、`websocket-server` に
> 1 件のローカル stash がありますが、stash は push されないためミラーには
> 含まれません（今回は対象外と判断済み）。未コミット変更は 3 件とも 0 件でした。

---

#### 第2段階 — 新リポジトリへ push ⛔ **未実施・要判断**

> **本番デプロイに影響します。実施前に下記「未決事項」を解決してください。**

**ステップ 1 — 移行先リポジトリを作成**

`kenjisciometa` 配下に空のプライベートリポジトリを 4 つ作成します。
同名で作成可能であることは確認済みです（名前衝突なし）。

```bash
for r in ReactRestaurantPOS websocket-server subscription-web scioweb; do
  gh repo create "kenjisciometa/$r" --private
done
```

**ステップ 2 — push --mirror で全履歴を移行**

```bash
cd /Users/kenjiyano/Documents/Sciometa/backup/github-mirror
for r in ReactRestaurantPOS websocket-server subscription-web scioweb; do
  git -C "$r.git" push --mirror "https://github.com/kenjisciometa/$r.git"
done
```

**ステップ 3 — 移行先の完全性を検証**

移行元と同じく、ブランチ先端 SHA で照合します。

```bash
for r in ReactRestaurantPOS websocket-server subscription-web scioweb; do
  gh api "repos/TunaInanamu/$r/branches"   --paginate --jq '.[] | "\(.name) \(.commit.sha)"' | sort > /tmp/old_$r.txt
  gh api "repos/kenjisciometa/$r/branches" --paginate --jq '.[] | "\(.name) \(.commit.sha)"' | sort > /tmp/new_$r.txt
  diff /tmp/old_$r.txt /tmp/new_$r.txt && echo "$r: 一致"
done
```

**ステップ 4 — default branch を合わせる**

`--mirror` は default branch 設定を移送しません。**手動で設定が必要です。**

| リポジトリ | default branch |
|---|---|
| `ReactRestaurantPOS` | `main` |
| `websocket-server` | **`master`** |
| `subscription-web` | `main` |
| `scioweb` | **`stage`** |

```bash
gh repo edit kenjisciometa/websocket-server --default-branch master
gh repo edit kenjisciometa/scioweb          --default-branch stage
```

**ステップ 5 — GitHub Actions Secrets を再設定**

> **ここが実質的なボトルネックです。**
> **GitHub Secrets は登録後に値を読み出せません。**
> 旧リポジトリからコピーすることは**不可能**です。1Password 等の保管元から
> 値を用意してください。用意できないと push しても自動デプロイが動きません。

必要な Secrets（リポジトリにより異なる）:

| Secret | 用途 |
|---|---|
| `VPN_PSK` | IPsec トンネル確立 |
| `SERVER_IP` | デプロイ先 |
| `SSH_USER` | デプロイユーザー |
| `SSH_PRIVATE_KEY` | デプロイ鍵 |
| `SLACK_WEBHOOK_URL` | 通知（一部のみ） |

```bash
# 各リポジトリで設定（値は対話入力）
gh secret set VPN_PSK --repo kenjisciometa/<repo>
```

> **§B-4（PSK ローテーション）を実施する場合は、この移行と同時に行うと
> 二度手間を避けられます。** 新 PSK を最初から新リポジトリへ登録してください。

**ステップ 6 — サーバー上の clone の remote を変更**

`external01` 上の作業ディレクトリの向き先を変更します。

```bash
cd /opt/sciometa/servers/<各リポジトリ>
git remote set-url origin https://github.com/kenjisciometa/<repo>.git
git remote -v   # 確認
```

> **`prod/subscription-web` は `deploy` ユーザー所有**のため、
> そのままでは `dubious ownership` エラーになります。
> `sudo -u deploy git ...` を使うか `safe.directory` に登録してください
> （`sudo` はパスワード必須のため非対話では実行できません）。

**ステップ 7 — デプロイ動作確認**

各リポジトリで `Actions` → `Run workflow`（`workflow_dispatch`）を手動実行し、
VPN 確立 → SSH → デプロイまで通ることを確認します。
**4 リポジトリすべてで一度ずつ流してください。**

---

#### 未決事項（第2段階の着手前に決定が必要）

| # | 事項 | 備考 |
|---|---|---|
| 1 | **Actions Secrets の値の入手** | 読み出し不可。保管元から用意が必要。**最大のボトルネック** |
| 2 | **実施タイミング** | デプロイが走らない時間帯を確保 |
| 3 | 新リポジトリ名を同名とするか | 名前衝突がないことは確認済み。同名で作成可能 |
| 4 | 旧リポジトリの扱い | 本人へ削除依頼するか、放置か |
| 5 | Issue / PR の引き継ぎ要否 | `--mirror` では移行されない |
| 6 | `scioweb` の本番コンテナ特定 | 他 3 件と異なり未確認 |

#### ロールバック

第2段階は**既存の本番リポジトリを一切変更しません**（新リポジトリを作って
push するだけ）。問題が起きた場合は remote を旧 URL へ戻すだけで復旧します。

```bash
git remote set-url origin https://github.com/TunaInanamu/<repo>.git
```

> 旧リポジトリは**移行成功を十分に確認するまで削除しないでください。**

---

## §C 残課題（今回の対応範囲外・中長期）

| # | 課題 | 理由・推奨対応 |
|---|---|---|
| C-1 | **`external01` の共有アカウント構造** | 5名以上が同一アカウントを共有。「誰が何をしたか」がログから追跡不能。異動のたびに全体を疑う必要が生じる。→ 個人ごとのアカウント発行、または `AuthorizedKeysCommand` による集中管理へ移行 |
| C-2 | **ローカルファイアウォール不在** | UFW 未導入。FortiGate 単一障害点。→ 最低限 MySQL/Redis を `127.0.0.1` バインドに変更、または UFW 導入 |
| C-3 | **MySQL/Redis の全インターフェース公開** | `0.0.0.0:5306`, `0.0.0.0:6380` 等。Redis は通常無認証。→ docker-compose の ports を `127.0.0.1:` プレフィックス付きに変更 |
| C-4 | **nginx allowlist の帰属不明** | 各 IP が誰のものか記録なし。→ snippets に集約し帰属コメントを付与（§A-7） |
| C-5 | **個人 Gmail 鍵の混在** | `akihiro.fin@gmail.com` が本番サーバーに登録。現役利用中（最終 2026-09-18）。→ 会社ドメイン鍵への移行を検討 |
| C-6 | **`sciometa-pos-dev` の `allow all` 上書き** | `deny all` を一部 location が無効化。意図的か要確認 |
| C-7 | ~~**git 管理外プロジェクト**~~ **→ 解決（2026-09-21）** | `prod/subscription-web` = `TunaInanamu/subscription-web`（§B-6 移行対象）、`dev/receipt-scanner` = `kenjisciometa/receipt-scanner` と特定。サーバー上の `.git` 不在自体は未解消のため、§B-6 ステップ6 で remote を設定すること |
| C-9 | **本番リポジトリの個人アカウント所有** | 本件の根本原因。4 リポジトリが個人アカウント配下で本番稼働していた。→ §B-6 で移行。今後は**本番リポジトリを個人アカウントに置かない**運用ルールの明文化を推奨 |
| C-10 | **Secrets の保管元が不明確** | GitHub Secrets は読み出し不可のため、移行・ローテーション時に原本が必要。→ 1Password 等への集約と、リポジトリ単位の必要 Secrets 一覧の整備を推奨 |
| C-8 | **`LogLevel VERBOSe` の綴り誤り** | 動作はするが、設定の意図が不明瞭。`VERBOSE` に修正推奨 |

---

## §D 作業チェックリスト

実施時にコピーして使ってください。

```
事前準備
  [ ] keisuke 氏へ鍵削除の事前周知（最終使用 2026-09-17・現役のため必須）
  [ ] 作業ウィンドウ確保（B-4 実施時のみ）
  [ ] Tailscale 経由の復旧経路を確認（100.108.89.6）

B-1. SSH 鍵失効  ★最優先・1分・影響なし
  [ ] authorized_keys をバックアップ
  [ ] keisuke 鍵を削除
  [ ] ssh-keygen -lf で削除を確認
  [ ] （任意）重複 #5 / 未使用 #2 を整理

B-2. GitHub 権限剥奪  ★推奨・5分  ※当社所有の4件のみ
  [ ] kenjisciometa/sciometapos
  [ ] kenjisciometa/shift-management-app
  [ ] kenjisciometa/accountant-app
  [ ] kenjisciometa/recipe-app
  [ ] Organization People からも削除
  [ ] Deploy keys を確認
  ※ TunaInanamu/* の4件は剥奪不能 → B-6 で対応

B-3. FortiGate 管理者  5分
  [ ] System > Administrators で該当アカウントを Disable
  [ ] Admin Profiles の super_admin 割当を確認
  [ ] User Groups の棚卸し
  [ ] SSL-VPN Portal Mapping を確認

B-4. PSK ローテーション  条件付き・15分＋検証
  [ ] 実施要否を判断（B-2 で足りるなら不要）
  [x] 所属不明2件のリポジトリを特定（2026-09-21 完了）
  [ ] 新 PSK を生成（openssl rand -hex 32 推奨）
  [ ] 1Password に保管
  [ ] GitHub Secrets を 9 リポジトリすべて更新  ← 先
  [ ] FortiGate の Pre-shared Key を変更        ← 後
  [ ] workflow_dispatch で検証
  [ ] 9 リポジトリすべてでデプロイ成功を確認
  ※ B-6 実施時は、移行後の新リポジトリへ新 PSK を登録（同時実施を推奨）

B-5. FortiGate ポリシー棚卸し  15分
  [ ] Virtual IPs: 2200(SSH) の要否判断
  [ ] Virtual IPs: 5306/6380/9079/8079 が無いことを確認
  [ ] Firewall Policy: Source=all の洗い出し
  [ ] 管理系ポート(9091/9007/19999/8089)の外部公開確認

B-6. リポジトリ移行  ★重要
  第1段階: ミラーバックアップ（読み取りのみ・影響なし）
  [x] ReactRestaurantPOS  3,967 commits / 83 branches / 検証済
  [x] websocket-server      235 commits / 12 branches / 検証済
  [x] subscription-web      192 commits /  5 branches / 検証済
  [ ] scioweb  ← ★未取得（4件目の判明が後だったため）
  [ ] バックアップを external01 等へ複製（現状ローカル1箇所のみ）

  第2段階: 新リポジトリへ push（本番影響あり・要判断）
  [ ] Actions Secrets の値を保管元から用意  ← ★最大のボトルネック
  [ ] 実施タイミングを決定（デプロイが走らない時間帯）
  [ ] kenjisciometa 配下に空リポジトリ4件を作成
  [ ] push --mirror で移行
  [ ] ブランチ先端 SHA で移行先を検証
  [ ] default branch を設定（websocket-server=master, scioweb=stage）
  [ ] Actions Secrets を再設定
  [ ] サーバー上の clone の remote を変更
      （prod/subscription-web は deploy ユーザー所有に注意）
  [ ] 4リポジトリすべてでデプロイ動作確認
  [ ] 旧リポジトリの扱いを決定（削除依頼 / 放置）

事後
  [ ] 1〜2週間後、auth.log に削除鍵の試行がないことを確認
  [ ] FortiGate アカウントを Disable → Delete へ
  [ ] §C の残課題をチケット化
  [ ] 移行成功の確認後、旧リポジトリの削除を本人へ依頼
```

---

## 付録: 調査に使用したコマンド

再監査時に利用してください。

```bash
# 鍵台帳（フィンガープリント＋使用実績）
S=/tmp/auth_sorted.log
{ zcat /var/log/auth.log.4.gz /var/log/auth.log.3.gz /var/log/auth.log.2.gz 2>/dev/null; \
  cat /var/log/auth.log.1 /var/log/auth.log 2>/dev/null; } > "$S"
cd /home/external01/.ssh
while read -r line; do
  [ -z "$line" ] && continue
  fp=$(echo "$line" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')
  cmt=$(echo "$line" | awk '{$1="";$2="";print}' | sed 's/^  *//')
  acc=$(grep -F "$fp" "$S" | grep -c 'Accepted publickey')
  last=$(grep -F "$fp" "$S" | grep 'Accepted publickey' | tail -1 | awk '{print $1" "$2}')
  echo "$cmt | $fp | accepted=$acc | last=${last:-none}"
done < authorized_keys

# ログの連結順に注意（ローテート分を古い順に並べること）

# VPN_PSK 参照リポジトリの洗い出し
cd /opt/sciometa/servers
for f in $(grep -rl 'VPN_PSK' . | grep '\.github/workflows/'); do
  d=${f%%/.github/workflows/*}
  echo "$(basename $f) $(git -C "$d" remote get-url origin 2>/dev/null || echo '<no-remote>')"
done | sort -k2

# 公開ポートの確認
ss -tulpn | grep -E '0\.0\.0\.0'

# Tailscale 端末一覧
tailscale status
```

---

*調査実施: 2026-09-21 / 対象ログ期間: 2026-08-23 〜 2026-09-21*
