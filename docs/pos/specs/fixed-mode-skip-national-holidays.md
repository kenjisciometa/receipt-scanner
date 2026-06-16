# Fixed Mode: 休日スキップ設定 — 定義書

## 1. Overview

Clock-In Mode の Fixed モードにおいて、休日（National Holiday + Schedule Annotation の Closed）の扱いを従業員ごとに設定可能にする。

### 現状の問題

- Cron Job（`auto-generate-time-entries`）は Fixed モードの祝日チェックに `organization_holidays` テーブル（カスタム祝日）のみ使用
- `date-holidays` パッケージによる National Holiday 検出はカレンダー表示にのみ使用されており、TimeEntry 自動生成には反映されていない
- Schedule ページの Add Annotation で設定された `close` ステータスの日（臨時休業・年末年始等）も TimeEntry 自動生成に反映されていない
- 従業員によっては祝日・休業日も出勤する場合があり、一律スキップでは運用が合わない

### 解決方針

`profiles` テーブルに `fixed_skip_national_holidays` フラグを追加し、従業員ごとに National Holiday **および** Schedule Annotation (Closed) の自動スキップ ON/OFF を設定可能にする。

### スキップ対象の整理

Fixed モードの TimeEntry 自動生成において、以下の3種類の「休日」が存在する:

| # | 種類 | データソース | スキップ制御 |
|---|------|-------------|-------------|
| 1 | カスタム祝日 | `organization_holidays` テーブル | **常にスキップ**（既存動作、変更なし） |
| 2 | National Holiday | `date-holidays` パッケージ + `organizations.settings.country` | `fixed_skip_national_holidays` フラグで制御 |
| 3 | Schedule Annotation (Closed) | `schedule_annotations` テーブル (`status = 'close'`) | `fixed_skip_national_holidays` フラグで制御 |

> **設計判断**: National Holiday と Closed Annotation を同一フラグで制御する理由:
> - どちらも「営業していない日」という同じ意味合い
> - 「祝日は休むが臨時休業日は出勤する」というケースは実運用上ほぼない
> - フラグを分けると UI が煩雑になる（2つの Switch が並ぶ）
> - フラグ名は `fixed_skip_national_holidays` だが、実質的には「祝日・休業日スキップ」として機能する

---

## 2. データモデル変更

### 2.1 profiles テーブル（カラム追加）

| カラム名 | 型 | デフォルト | 説明 |
|----------|----|----------|------|
| `fixed_skip_national_holidays` | `BOOLEAN` | `true` | Fixed モード: National Holiday および Closed Annotation を自動でスキップするか |

```sql
ALTER TABLE profiles
ADD COLUMN fixed_skip_national_holidays BOOLEAN NOT NULL DEFAULT true;
```

#### デフォルト値の意図

- `true`（スキップ）がデフォルト — 既存の定義書（§4.4）で「祝日以外の指定曜日に固定時間で自動生成」と定義されており、現行の期待動作と一致
- 祝日・休業日も勤務する場合は管理者が明示的に `false` に変更する

---

## 3. Cron Job 変更

### 3.1 対象ファイル

`src/app/api/cron/auto-generate-time-entries/route.ts`

### 3.2 変更内容

#### ProfileRow インターフェースに追加

```typescript
interface ProfileRow {
  // ... existing fields ...
  fixed_skip_national_holidays: boolean;
}
```

#### SELECT クエリに追加

```typescript
.select("id, organization_id, clock_in_mode, ..., fixed_skip_national_holidays, status")
```

#### 組織の country 取得を追加

POS DB から `organizations.settings` を取得し、`settings.country` を抽出する。

```typescript
const { data: orgs } = await posClient
  .from("organizations")
  .select("id, timezone, settings")
  .in("id", orgIds);

const orgTimezones = new Map<string, string>();
const orgCountries = new Map<string, string>();
for (const org of orgs ?? []) {
  orgTimezones.set(org.id, org.timezone ?? "UTC");
  const settings = org.settings as { country?: string } | null;
  if (settings?.country) {
    orgCountries.set(org.id, settings.country);
  }
}
```

#### Schedule Annotation (Closed) の一括取得を追加

組織ごとに対象日に該当する `close` ステータスの annotation を取得する。

```typescript
// Fetch closed annotations for all orgs on the target date
// Note: targetDateStr is calculated per-org, so we fetch broadly and filter per-org later
const { data: closedAnnotations } = await supabase
  .from("schedule_annotations")
  .select("organization_id, start_date, end_date, title")
  .in("organization_id", orgIds)
  .eq("status", "close");

// Build a lookup: orgId → array of { start_date, end_date, title }
const orgClosedAnnotations = new Map<string, Array<{ start_date: string; end_date: string; title: string }>>();
for (const a of closedAnnotations ?? []) {
  const list = orgClosedAnnotations.get(a.organization_id) ?? [];
  list.push({ start_date: a.start_date, end_date: a.end_date, title: a.title });
  orgClosedAnnotations.set(a.organization_id, list);
}
```

#### National Holiday チェック + Closed Annotation チェック追加（Fixed モード処理内）

既存の `organization_holidays`（カスタム祝日）チェックの**後**に追加する。

```typescript
// Check national holidays and closed annotations (controlled by same flag)
if (profile.fixed_skip_national_holidays) {
  // 3a. National Holiday check (date-holidays package)
  const countryCode = orgCountries.get(orgId);
  if (countryCode) {
    const nationalHolidays = getHolidaysForRange(
      countryCode,
      new Date(`${targetDateStr}T00:00:00Z`),
      new Date(`${targetDateStr}T23:59:59Z`)
    );
    if (nationalHolidays.has(targetDateStr)) {
      fixedResult.skipped++;
      await logAutoGenEntry(supabase, {
        organization_id: orgId,
        user_id: profile.id,
        target_date: targetDateStr,
        mode: "fixed",
        status: "skipped",
        skip_reason: `National holiday: ${nationalHolidays.get(targetDateStr)![0].name}`,
      });
      continue;
    }
  }

  // 3b. Closed Annotation check (schedule_annotations)
  const closedAnns = orgClosedAnnotations.get(orgId) ?? [];
  const matchingClosed = closedAnns.find(
    (a) => targetDateStr >= a.start_date && targetDateStr <= a.end_date
  );
  if (matchingClosed) {
    fixedResult.skipped++;
    await logAutoGenEntry(supabase, {
      organization_id: orgId,
      user_id: profile.id,
      target_date: targetDateStr,
      mode: "fixed",
      status: "skipped",
      skip_reason: `Closed: ${matchingClosed.title}`,
    });
    continue;
  }
}
```

### 3.3 処理フロー（更新後）

```
Fixed モード処理フロー:
  1. 曜日チェック（fixed_work_days）
  2. カスタム祝日チェック（organization_holidays テーブル）← 既存・常時実行
  3. National Holiday チェック（date-holidays パッケージ）← 新規
     - profile.fixed_skip_national_holidays = true の場合のみ実行
     - organization.settings.country が未設定の場合はスキップ（チェックしない）
  4. Closed Annotation チェック（schedule_annotations テーブル）← 新規
     - profile.fixed_skip_national_holidays = true の場合のみ実行
     - targetDate が start_date〜end_date の範囲内に含まれるかチェック
  5. 既存エントリ重複チェック
  6. TimeEntry 生成
```

### 3.4 チェック順序の理由

| 順序 | チェック | 理由 |
|------|---------|------|
| 1 | 曜日 | 最も高速（メモリ内配列チェック） |
| 2 | カスタム祝日 | DB クエリ済み（一括取得）、常に適用 |
| 3 | National Holiday | `date-holidays` ライブラリ呼び出し、フラグ制御 |
| 4 | Closed Annotation | DB クエリ済み（一括取得）、フラグ制御、日付範囲マッチ |
| 5 | 既存エントリ | DB クエリが必要、最後にチェック |

> National Holiday と Closed Annotation は同じ `if (profile.fixed_skip_national_holidays)` ブロック内で順次チェック。どちらかでスキップが確定すれば `continue` で即座に次の従業員へ。

---

## 4. API 変更

### 4.1 team/members/[id]/route.ts

#### UpdateMemberRequest に追加

```typescript
fixed_skip_national_holidays?: boolean;
```

#### PUT whitelist に追加

```typescript
if (body.fixed_skip_national_holidays !== undefined) {
  updateData.fixed_skip_national_holidays = body.fixed_skip_national_holidays;
}
```

#### GET/PUT の SELECT に追加

```
fixed_skip_national_holidays
```

### 4.2 profile/route.ts

#### GET の SELECT に追加

```
fixed_skip_national_holidays
```

---

## 5. React UI 変更

### 5.1 対象ファイル

`src/components/team/employee-dialog.tsx`

### 5.2 formData に追加

```typescript
fixedSkipNationalHolidays: true,
```

### 5.3 useEffect 初期化に追加

```typescript
fixedSkipNationalHolidays:
  (employee as Record<string, unknown>).fixed_skip_national_holidays !== false,
```

> `!== false` を使用 — DB の `DEFAULT true` と合わせ、`null`/`undefined` 時も `true` として扱う

### 5.4 Fixed Schedule Settings 内に Switch を追加

Work Days の下、Default Location の上に配置。

```
┌─ Fixed Schedule Settings ─────────────────────┐
│  Start Time / End Time                         │
│  Break Duration                                │
│  Work Days: [Mon][Tue][Wed][Thu][Fri]           │
│                                                │
│  📅 Skip Holidays & Closed Days      [━━━ ON]  │
│  "Automatically skip work on national holidays │
│   and days marked as closed on the schedule"    │
│                                                │
│  📍 Default Location               [▼ Select]  │
└────────────────────────────────────────────────┘
```

UIコンポーネント:

```tsx
{/* Skip National Holidays & Closed Days */}
<div className="flex items-center justify-between rounded-lg border p-3">
  <div className="space-y-0.5">
    <div className="flex items-center gap-2">
      <CalendarDays className="h-4 w-4 text-muted-foreground" />
      <Label htmlFor="fixedSkipNationalHolidays" className="font-medium">
        Skip Holidays & Closed Days
      </Label>
    </div>
    <p className="text-sm text-muted-foreground">
      Automatically skip work on national holidays and days
      marked as closed on the schedule
    </p>
  </div>
  <Switch
    id="fixedSkipNationalHolidays"
    checked={formData.fixedSkipNationalHolidays}
    onCheckedChange={(checked) =>
      setFormData((prev) => ({ ...prev, fixedSkipNationalHolidays: checked }))
    }
  />
</div>
```

### 5.5 handleSubmit に追加

```typescript
fixed_skip_national_holidays: formData.clockInMode === "fixed"
  ? formData.fixedSkipNationalHolidays
  : null,
```

---

## 6. Flutter 変更

### 6.1 profile.dart

```dart
@JsonKey(name: 'fixed_skip_national_holidays') @Default(true) bool fixedSkipNationalHolidays,
```

### 6.2 team_api_service.dart

`updateTeamMember` に追加:

```dart
bool? fixedSkipNationalHolidays,
```

`if (clockInMode != null)` の spread ブロック内に追加:

```dart
'fixed_skip_national_holidays': fixedSkipNationalHolidays ?? true,
```

### 6.3 profile_repository.dart

パススルー追加:

```dart
fixedSkipNationalHolidays: updates['fixed_skip_national_holidays'] as bool?,
```

### 6.4 employee_management_screen.dart（任意）

Flutter 側の従業員編集画面にも同様の Switch を追加（React と同等の UI）。

### 6.5 build_runner 再実行

```bash
cd flutter_app
dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs
```

---

## 7. 変更対象ファイル一覧

| # | ファイル | 変更内容 |
|---|---------|---------|
| 1 | DB migration | `fixed_skip_national_holidays` カラム追加 |
| 2 | `src/app/api/cron/auto-generate-time-entries/route.ts` | National Holiday チェック + Closed Annotation チェック追加、`settings.country` 取得、`schedule_annotations` 取得 |
| 3 | `src/app/api/team/members/[id]/route.ts` | whitelist + SELECT に追加 |
| 4 | `src/app/api/profile/route.ts` | SELECT に追加 |
| 5 | `src/components/team/employee-dialog.tsx` | formData + UI (Switch) + handleSubmit |
| 6 | `flutter_app/lib/data/models/profile.dart` | `fixedSkipNationalHolidays` フィールド追加 |
| 7 | `flutter_app/lib/data/models/profile.g.dart` | build_runner で再生成 |
| 8 | `flutter_app/lib/data/api_services/team_api_service.dart` | パラメータ追加 |
| 9 | `flutter_app/lib/data/repositories/profile_repository.dart` | パススルー追加 |
| 10 | `flutter_app/lib/presentation/screens/admin/employee_management_screen.dart` | Flutter UI (任意) |

---

## 8. 後方互換性

| 対象 | 影響 |
|------|------|
| 旧 Flutter アプリ | `fixed_skip_national_holidays` は JSON にあっても `json_serializable` の `@Default(true)` で安全にデシリアライズ。旧アプリが `true` を返す → 祝日スキップ動作を維持 |
| 旧 API リクエスト | `body.fixed_skip_national_holidays !== undefined` ガードにより、フィールド未送信時は DB 値を保持 |
| DB デフォルト | `DEFAULT true` — 既存レコードは自動的に祝日スキップ有効（現行動作と同一） |

---

## 9. エッジケース

| ケース | 挙動 |
|--------|------|
| 組織の country 未設定 | National Holiday チェックをスキップ（祝日なしとして扱う）。Closed Annotation チェックは country に依存しないため正常に動作 |
| `fixed_skip_national_holidays = true` + country 未設定 | National Holiday スキップは実質無効。Closed Annotation スキップは有効 |
| `fixed_skip_national_holidays = false` | National Holiday チェックも Closed Annotation チェックも実行しない → 祝日・休業日でも TimeEntry 生成 |
| カスタム祝日と National Holiday が同日 | カスタム祝日が先にチェックされスキップ。`fixed_skip_national_holidays` の値に関係なく、カスタム祝日は常にスキップ |
| カスタム祝日と Closed Annotation が同日 | 同上。カスタム祝日が先にスキップ |
| National Holiday と Closed Annotation が同日 | National Holiday が先にチェックされスキップ。ログの skip_reason は `National holiday: ...` |
| Closed Annotation が複数日にまたがる | `targetDateStr >= start_date && targetDateStr <= end_date` で日付範囲マッチ |
| `clock_in_mode` を `fixed` 以外に変更 | handleSubmit で `fixed_skip_national_holidays: null` を送信 → DB 値クリア。次に `fixed` に戻した際は `DEFAULT true` が適用 |
| Closed Annotation が後から追加・削除 | Cron 実行時のリアルタイムデータを使用。過去に生成済みの TimeEntry は影響を受けない |
