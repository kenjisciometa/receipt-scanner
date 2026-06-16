# Clock-In Mode Feature Specification

## 1. Overview

従業員ごとに打刻（Clock In/Out）の運用モードを設定可能にする機能。
レストランの運用スタイルに合わせて、手動打刻・シフト連動・固定勤務の3モードを提供する。

### 背景となる要望

| # | 要望元 | 内容 |
|---|--------|------|
| A | レストランA | 全従業員がClock In/Outを使用しない。予定シフト時間で給与計算。ただし会計士連携のためActual Clock In/Out（TimeEntry）は必要。Sick leave等のステータス変更も必要。 |
| B | レストランB | 特定従業員のみClock In/Out不要。Shiftも作成せず、祝日以外の平日に毎日8時間の固定勤務として自動記録したい。 |

---

## 2. Clock-In Mode 定義

`Profile`モデルに`clock_in_mode`フィールドを追加し、以下の3モードを定義する。

| モード | 値 | 説明 | Clock In/Out UI | TimeEntry生成方法 | Shift必要 |
|--------|----|------|-----------------|-------------------|-----------|
| Manual | `manual` | 現行通り。従業員がアプリで打刻する | 表示 | 従業員がClock In/Outで生成 | 任意 |
| Scheduled | `scheduled` | シフトの予定時間でTimeEntryを自動生成 | 非表示 | Cron Jobがシフト終了後に自動生成 | **必須** |
| Fixed | `fixed` | 祝日以外の指定曜日に固定時間でTimeEntryを自動生成 | 非表示 | Cron Jobが毎日自動生成 | 不要 |

### デフォルト値

- 新規・既存全従業員: `manual`（破壊的変更なし）

---

## 3. データモデル変更

### 3.1 profiles テーブル（カラム追加）

| カラム名 | 型 | デフォルト | 説明 |
|----------|----|----------|------|
| `clock_in_mode` | `TEXT` | `'manual'` | 打刻モード (`manual` / `scheduled` / `fixed`) |
| `fixed_work_start_time` | `TEXT` | `NULL` | Fixed モード: 勤務開始時刻 (HH:mm) |
| `fixed_work_end_time` | `TEXT` | `NULL` | Fixed モード: 勤務終了時刻 (HH:mm) |
| `fixed_work_days` | `INTEGER[]` | `NULL` | Fixed モード: 勤務曜日 (1=月〜7=日, ISO 8601) |
| `fixed_work_location_id` | `UUID` | `NULL` | Fixed モード: デフォルト勤務場所 (FK → locations) |
| `fixed_break_minutes` | `INTEGER` | `0` | Fixed モード: 休憩時間（分） |

#### Validation Constraints

- `clock_in_mode`が`fixed`の場合、`fixed_work_start_time`, `fixed_work_end_time`, `fixed_work_days`は必須
- `fixed_work_days`の値は1〜7の範囲内
- `fixed_work_start_time` < `fixed_work_end_time`（日跨ぎは非対応）

### 3.2 organization_holidays テーブル（新規作成）

Fixed モードで祝日を除外するためのテーブル。

| カラム名 | 型 | 説明 |
|----------|----|------|
| `id` | `UUID` (PK) | 主キー |
| `organization_id` | `UUID` (FK) | 組織ID |
| `date` | `DATE` | 祝日の日付 |
| `name` | `TEXT` | 祝日名（例: "元旦", "Christmas"） |
| `is_recurring` | `BOOLEAN` | 毎年繰り返すかどうか（デフォルト: false） |
| `created_at` | `TIMESTAMPTZ` | 作成日時 |
| `updated_at` | `TIMESTAMPTZ` | 更新日時 |

```sql
CREATE TABLE organization_holidays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  name TEXT,
  is_recurring BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(organization_id, date)
);

CREATE INDEX idx_org_holidays_org_date ON organization_holidays(organization_id, date);
```

### 3.3 auto_generated_entries ログテーブル（新規作成）

自動生成の実行履歴を記録し、重複防止・トラブルシューティングに使用。

| カラム名 | 型 | 説明 |
|----------|----|------|
| `id` | `UUID` (PK) | 主キー |
| `organization_id` | `UUID` (FK) | 組織ID |
| `user_id` | `UUID` | 対象従業員ID |
| `target_date` | `DATE` | 対象日付 |
| `mode` | `TEXT` | `scheduled` / `fixed` |
| `time_entry_id` | `UUID` | 生成されたTimeEntryのID |
| `shift_id` | `UUID` | 元になったShiftのID（scheduled モードのみ） |
| `status` | `TEXT` | `success` / `skipped` / `error` |
| `skip_reason` | `TEXT` | スキップ理由（祝日、既存エントリあり等） |
| `created_at` | `TIMESTAMPTZ` | 実行日時 |

---

## 4. 自動生成ロジック（Cron Job）

### 4.1 既存Cronインフラの活用

既存の Host Cron インフラ（`ops/cron-host/`）をそのまま活用する。新たなスケジューラやインフラ構築は不要。

**既存アーキテクチャ:**
```
/etc/cron.d/shift-management (crontab)
  → /usr/local/sbin/shift-cron-call (curl wrapper)
    → Next.js API /api/cron/* (verifyCronAuth + Supabase)
```

`shift-cron-call` により以下が自動的に適用される:
- `flock` による重複実行防止
- `--retry 2` によるリトライ
- `/var/log/shift-cron/` へのログ出力
- `logrotate` によるログローテーション

### 4.2 追加するエンドポイントとcrontabエントリ

#### 新規 API エンドポイント

```
GET /api/cron/auto-generate-time-entries
```

実装ファイル: `src/app/api/cron/auto-generate-time-entries/route.ts`

既存の `auto-clock-out/route.ts` と同じパターンで実装:
- `verifyCronAuth(request)` で認証
- `createDataClient()` で Shift DB (profiles, time_entries, shifts)
- `createPosClient()` で POS DB (organizations → timezone)
- エラーは per-user で収集、全体は fail しない

**レスポンス形式:**
```json
{
  "success": true,
  "data": {
    "target_date": "2026-05-30",
    "scheduled": { "processed": 15, "generated": 12, "skipped": 3 },
    "fixed":     { "processed": 5,  "generated": 4,  "skipped": 1 },
    "errors": []
  }
}
```

#### crontab への追加（1行のみ）

```diff
# /etc/cron.d/shift-management に追加

# ---------- Auto-generate time entries ----------
# Generate TimeEntries for scheduled/fixed clock-in mode employees.
# Runs daily at 02:00 UTC for the previous day.
0 2 * * * root /usr/local/sbin/shift-cron-call /api/cron/auto-generate-time-entries
```

デプロイ手順は既存と同一:
```bash
sudo install -o root -g root -m 644 "$REPO/cron.d/shift-management" /etc/cron.d/shift-management
sudo systemctl reload cron
```

### 4.3 Scheduled モード処理フロー

```
1. clock_in_mode = 'scheduled' の全従業員を取得（profiles テーブル）
2. 従業員を organization_id でグループ化
3. 各組織のタイムゾーンを取得（POS DB → organizations）
4. 対象日を算出（組織TZでの「昨日」）
5. 各従業員について:
   a. 対象日の全Shiftを取得（1日に複数シフトがある場合あり）
   b. 各Shiftについて:
      - 同一 shift_id に紐づく既存TimeEntryがあればスキップ（重複防止）
      - TimeEntryを生成:
        - clock_in_at = shift.start_time
        - clock_out_at = shift.end_time
        - shift_id = shift.id
        - is_manual = true
        - entry_type = 'work'
        - status = 'pending'
        - notes = 'Auto-generated from scheduled shift'
        - location_id = shift.location_id
      - auto_generated_entries にログ記録
6. Shiftがない日はスキップ（ログに記録）
```

> **Note**: 1日に複数シフト（例: 10:00-14:00 + 17:00-22:00）がある従業員の場合、
> シフトごとに個別のTimeEntryを生成する。重複チェックは shift_id 単位で行う。

### 4.4 Fixed モード処理フロー

```
1. clock_in_mode = 'fixed' の全従業員を取得（profiles テーブル）
2. 従業員を organization_id でグループ化
3. 各組織のタイムゾーンを取得（POS DB → organizations）
4. 対象日を算出（組織TZでの「昨日」）
5. 各従業員について:
   a. 対象日の曜日（ISO: 1=月〜7=日）がfixed_work_daysに含まれるかチェック
   b. 対象日がorganization_holidaysに登録されていないかチェック
      - is_recurring = true の場合、月日のみで照合
   c. 対象日に既存TimeEntryがあればスキップ（重複防止）
   d. TimeEntryを生成:
      - clock_in_at = 対象日 + fixed_work_start_time（組織TZ → UTC変換）
      - clock_out_at = 対象日 + fixed_work_end_time（組織TZ → UTC変換）
      - is_manual = true
      - entry_type = 'work'
      - status = 'pending'
      - notes = 'Auto-generated from fixed schedule'
      - location_id = fixed_work_location_id
      - break（fixed_break_minutes > 0の場合、シフト中間に自動挿入）
   e. auto_generated_entries にログ記録
6. 祝日・対象外曜日はスキップ（ログに記録）
```

### 4.5 重複防止ルール

以下の条件に一致するTimeEntryが既に存在する場合、生成をスキップする:

- 同一 `user_id`
- 同一日（組織タイムゾーン基準）
- `entry_type` が `work` または leave系（`sick_leave`, `vacation` 等）

これにより、管理者が先に手動でSick Leave等のエントリを作成していた場合、自動生成が上書きしない。

### 4.6 負荷見積もり

| 項目 | 値 |
|------|-----|
| 実行頻度 | 1日1回（02:00 UTC） |
| 対象データ量 | `scheduled`/`fixed`モードの従業員数（通常: 数人〜数十人/組織） |
| DB操作 | SELECT(従業員取得) + SELECT(重複チェック) + INSERT(TimeEntry生成) × 対象人数 |
| 1組織あたり想定実行時間 | < 1秒 |
| 全組織処理 | 組織数 × ~1秒（100組織でも < 2分） |
| 比較: auto-clock-out | 毎分実行・最大50件処理 → それより遥かに軽量 |

**結論: 既存の auto-clock-out（毎分実行）と比較して1/1440の頻度。負荷は完全に無視できる。**

### 4.7 既存 auto-clock-out との関係

| 項目 | auto-clock-out | auto-generate-time-entries |
|------|---------------|---------------------------|
| 頻度 | 毎分 | 1日1回 |
| 対象 | `manual`モードでClock In済みの従業員 | `scheduled`/`fixed`モードの従業員 |
| 処理 | 既存TimeEntryのclockOutAtを設定 | 新規TimeEntryをINSERT |
| 競合 | なし（対象モードが排他的） | なし |

`clock_in_mode = 'manual'` の従業員のみが auto-clock-out の対象となるため、両Cronが同一従業員に対して競合することはない。

---

## 5. Flutter アプリ側変更

### 5.1 Profile モデル拡張

```dart
// lib/data/models/profile.dart に追加
@JsonKey(name: 'clock_in_mode') @Default('manual') String clockInMode,
@JsonKey(name: 'fixed_work_start_time') String? fixedWorkStartTime,
@JsonKey(name: 'fixed_work_end_time') String? fixedWorkEndTime,
@JsonKey(name: 'fixed_work_days') List<int>? fixedWorkDays,
@JsonKey(name: 'fixed_work_location_id') String? fixedWorkLocationId,
@JsonKey(name: 'fixed_break_minutes') @Default(0) int fixedBreakMinutes,

// Helper getters
bool get isManualClockIn => clockInMode == 'manual';
bool get isScheduledClockIn => clockInMode == 'scheduled';
bool get isFixedClockIn => clockInMode == 'fixed';
bool get requiresManualClockIn => clockInMode == 'manual';
```

### 5.2 Clock In/Out UI 制御

**対象ファイル**: `time_clock_card.dart`, ダッシュボード画面

```dart
// Clock In/Out カードの表示制御
if (profile.requiresManualClockIn) {
  // 現行のClock In/Out UIを表示
  return TimeClockCard(...);
} else {
  // 「勤務は自動記録されます」等のメッセージを表示
  return AutoRecordInfoCard(mode: profile.clockInMode);
}
```

### 5.3 従業員管理画面の拡張

**対象ファイル**: `employee_management_screen.dart` または従業員編集ダイアログ

追加するUI要素:

```
┌─────────────────────────────────────┐
│ Clock-In Mode                       │
│ ┌─────────┐ ┌──────────┐ ┌───────┐ │
│ │ Manual  │ │Scheduled │ │ Fixed │ │
│ │  (●)    │ │  ( )     │ │  ( )  │ │
│ └─────────┘ └──────────┘ └───────┘ │
│                                     │
│ ── Fixed Mode Settings ──────────── │
│ (clockInMode == 'fixed' の場合表示)  │
│                                     │
│ Work Start Time:  [09:00]           │
│ Work End Time:    [17:00]           │
│ Break Minutes:    [60]              │
│ Work Days:                          │
│ [x]Mon [x]Tue [x]Wed [x]Thu [x]Fri │
│ [ ]Sat [ ]Sun                       │
│ Location: [Dropdown ▼]              │
└─────────────────────────────────────┘
```

### 5.4 祝日管理画面（新規）

**新規画面**: `holiday_management_screen.dart`

管理者が組織の祝日を登録・管理する画面。

```
┌─────────────────────────────────────┐
│ Holidays                    [+ Add] │
│─────────────────────────────────────│
│ 2026-01-01  New Year's Day     🔄  │
│ 2026-05-05  Children's Day     🔄  │
│ 2026-12-25  Christmas          🔄  │
│ 2026-12-31  Year-End Holiday        │
│                                     │
│ 🔄 = Recurring (毎年繰り返し)       │
└─────────────────────────────────────┘
```

### 5.5 Timesheet 画面での entryType 変更

**既存機能の拡張**: 自動生成されたTimeEntryに対して、管理者が`entryType`を変更可能にする。

対象ファイル: `timesheet_list_screen.dart`, `add_shift_dialog.dart`

```
┌─────────────────────────────────────┐
│ May 28, 2026 - Tanaka Taro          │
│ 09:00 - 17:00 (8h)                  │
│ Type: [Work ▼]  ← ドロップダウン     │
│       Work                          │
│       Sick Leave                    │
│       Vacation                      │
│       Personal                      │
│       Bereavement                   │
│ Status: Pending  [Approve]          │
│ Note: Auto-generated from shift     │
└─────────────────────────────────────┘
```

---

## 6. API 変更

### 6.1 Profile API

既存の`updateProfile` APIに新フィールドを追加（追加カラムがSupabase経由で自動的に対応）。

### 6.2 Holiday API

| Method | Endpoint | 説明 |
|--------|----------|------|
| GET | `/api/organization/holidays` | 祝日一覧取得 |
| POST | `/api/organization/holidays` | 祝日登録 |
| PUT | `/api/organization/holidays/:id` | 祝日更新 |
| DELETE | `/api/organization/holidays/:id` | 祝日削除 |

### 6.3 Auto-Generate Trigger API（管理者用）

| Method | Endpoint | 説明 |
|--------|----------|------|
| POST | `/api/time-clock/auto-generate` | 手動で自動生成を実行（テスト・リカバリ用） |

パラメータ:
- `organization_id` (必須)
- `target_date` (必須): 対象日
- `user_ids` (任意): 特定従業員のみ指定

---

## 7. 実装フェーズ

### Phase 1: Scheduled モード（要望A対応）

| # | タスク | 対象 | 詳細 |
|---|--------|------|------|
| 1-1 | DB マイグレーション（profiles カラム追加） | Supabase | `clock_in_mode`, `fixed_work_*` カラム追加 |
| 1-2 | auto_generated_entries ログテーブル作成 | Supabase | §3.3 参照 |
| 1-3 | Profile モデル拡張 | Flutter | `clockInMode` + helper getters |
| 1-4 | Clock In/Out UI の出し分けロジック | Flutter | `time_clock_card.dart` |
| 1-5 | 従業員編集画面に clockInMode 設定UI追加 | Flutter | `employee_management_screen.dart` |
| 1-6 | `/api/cron/auto-generate-time-entries` 実装 | Next.js | Scheduled モードのみ先行実装 |
| 1-7 | crontab にエントリ追加 | ops/cron-host | 1行追加 + デプロイ |
| 1-8 | Timesheet 画面で entryType 変更UI | Flutter | 既存画面の拡張 |

### Phase 2: Fixed モード + 祝日（要望B対応）

| # | タスク | 対象 | 詳細 |
|---|--------|------|------|
| 2-1 | organization_holidays テーブル作成 | Supabase | §3.2 参照 |
| 2-2 | Holiday API の実装 | Next.js | `/api/organization/holidays` CRUD |
| 2-3 | 祝日管理画面の実装 | Flutter | `holiday_management_screen.dart` |
| 2-4 | auto-generate-time-entries に Fixed ロジック追加 | Next.js | 既存エンドポイントに追加 |
| 2-5 | Fixed モード設定UI（勤務時間・曜日） | Flutter | 従業員編集画面に追加 |

### Phase 3: 運用改善

| # | タスク | 対象 | 詳細 |
|---|--------|------|------|
| 3-1 | 管理者向け自動生成ログ確認画面 | Flutter | auto_generated_entries 閲覧 |
| 3-2 | entryType 一括変更機能 | Flutter | 複数エントリの一括 sick_leave 変更等 |
| 3-3 | 手動トリガーAPI（リカバリ用） | Next.js | `/api/time-clock/auto-generate` POST |

---

## 8. 運用シナリオ

### シナリオ A: レストランA（全員 Scheduled モード）

```
1. 管理者が全従業員の clock_in_mode を 'scheduled' に設定
2. 管理者が通常通りシフトを作成・公開
3. 翌日深夜、Cron Jobが前日のシフトからTimeEntryを自動生成
4. 従業員Xが病欠:
   a. 管理者がTimesheet画面でXのTimeEntryを開く
   b. entryType を 'work' → 'sick_leave' に変更
5. 会計士は全従業員のTimeEntry（Actual Hours）をエクスポートして確認
```

### シナリオ B: レストランB（特定従業員のみ Fixed モード）

```
1. 管理者が特定従業員Yの clock_in_mode を 'fixed' に設定
   - 勤務時間: 09:00-17:00, 休憩60分
   - 勤務曜日: 月〜金
2. 管理者が組織の祝日を登録（元旦、GW等）
3. 毎日深夜、Cron Jobが:
   - 平日かつ祝日でない日 → TimeEntry自動生成
   - 土日・祝日 → スキップ
4. 他の従業員は clock_in_mode = 'manual' のまま → 従来通りClock In/Out
```

---

## 9. 既存機能との互換性

| 既存機能 | 影響 |
|----------|------|
| Clock In/Out | `manual`モードでは変更なし |
| Auto Clock Out | `manual`モードでのみ適用（`scheduled`/`fixed`はCronで生成するため不要） |
| Timesheet/Payroll | TimeEntryの構造は同一のため影響なし |
| PTO Request | 独立した機能。entryType変更と併用可能 |
| Shift Management | `scheduled`モードではShift必須。`fixed`モードでは不要 |
| Manual Time Entry | 全モードで管理者による手動作成・編集は引き続き可能 |
| Geofence | `manual`モードでのみ適用 |
| Netvisor/Procountor 給与連携 | 下記 §9.1 参照 |

### 9.1 給与連携（Netvisor / Procountor）への影響

自動生成されたTimeEntryは `is_manual = true` が設定される。
給与連携の auto-sync (`/api/netvisor/workday/auto-sync`, `/api/procountor/payroll/auto-sync`) が
`is_manual` フラグでエントリをフィルタしていないことを実装時に確認する必要がある。

**確認ポイント:**
- auto-sync が TimeEntry を取得する際のクエリ条件に `is_manual = false` 等のフィルタがないこと
- 自動生成エントリの `entry_type = 'work'` が正しく勤務時間として集計されること
- `entry_type = 'sick_leave'` 等に変更されたエントリが給与連携で正しく区分されること

---

## 10. セキュリティ・権限

| 操作 | 権限 |
|------|------|
| clock_in_mode の変更 | owner, admin のみ |
| 祝日の管理 | owner, admin のみ |
| 自動生成エントリの entryType 変更 | owner, admin, manager |
| 自動生成ログの閲覧 | owner, admin |
| 手動トリガー API | owner, admin |
