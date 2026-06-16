# Flutter シフト作成時の重複・コンフリクト検出

## 概要

React版シフト管理で実装済みの以下3機能を、Flutter版にも実装する。

1. **単発シフト作成時の従業員フィルタリング** — 同日に既存シフトがある従業員を候補から除外
2. **Repeatシフト作成時の重複検出** — 各日程の既存シフトとの重複を事前チェックし、Skip / Create All を選択可能に
3. **Unavailability / PTO コンフリクト警告** — シフト作成後、バックエンドから返される warnings をもとに警告ダイアログを表示し、Undo / Skip Conflicts / Keep All を選択可能に

## 対象ファイル

- `shift-management-app/flutter_app/lib/presentation/screens/admin/shift_management_screen.dart`
  - `_ShiftFormSheetState` クラス

## 現状の動作

### React（参考実装）

**従業員フィルタリング:**
- `shift-dialog.tsx:263-279` の `availableTeamMembers` useMemo
- 新規作成時、選択日の全シフトを走査し `user_id` / `employee_id` が一致する従業員をドロップダウンから除外
- 編集時はフィルタリングしない（再割り当て可能）

**Repeat重複チェック:**
- `proceedWithOverlapCheck()` で全日程の重複を `Promise.all()` で並列チェック
- 重複があれば「Cancel / Create Anyway」ダイアログを表示

**Unavailability/PTO 警告（事後チェック）:**
- バックエンドAPI (`POST /api/shifts`, `POST /api/shifts/bulk`) がシフト作成時に Unavailability / PTO / Closed Day をチェック
- レスポンスに `warnings: ShiftWarning[]` と `conflicting_shift_ids: string[]` を含む
- `block_shifts_during_unavailability` 設定が true の場合 → シフトを作成せずスキップ（`skipped_due_to_unavailability`）
- false の場合 → シフトは作成するが警告を返す（`unavailability_conflict`, `pto_conflict`）
- フロントエンドは warnings を受け取り、「Undo / Skip Conflicts / Keep All」ダイアログを表示

### Flutter（現状）
- `assignableEmployeesProvider` が全組織メンバーを返す（フィルタリングなし）
- 単発シフト保存時のみ `_checkOverlappingShifts()` で重複警告を表示（Cancel / Create Anyway）
- **Repeatシフト作成時は重複チェックが一切ない**
- **Unavailability / PTO コンフリクトチェックは一切ない**
- ドロップダウンには常に全従業員が表示される
- Unavailability/PTO のモデル・リポジトリ・APIサービスは既に実装済み（利用可能）

### Flutter側の既存リソース（活用可能）

| リソース | ファイル | 用途 |
|----------|---------|------|
| `Unavailability` モデル | `lib/data/models/unavailability.dart` | 日付・時間帯・all_day・group_id |
| `PtoRequest` モデル | `lib/data/models/pto_request.dart` | 日付範囲・pto_type・status・half_day |
| `ScheduleAnnotation` モデル | `lib/data/models/schedule_annotation.dart` | 日付範囲・status (open/close/info) |
| `UnavailabilityRepository` | `lib/data/repositories/unavailability_repository.dart` | `getOrganizationUnavailabilities()`, `isEmployeeAvailable()` |
| `PtoRepository` | `lib/data/repositories/pto_repository.dart` | `getOrganizationPtoRequests()` |
| `ScheduleAnnotationRepository` | `lib/data/repositories/schedule_annotation_repository.dart` | `getCloseAnnotations()`, `isDateClosed()` |

---

## 変更仕様

### 機能1: 単発シフト作成時の従業員フィルタリング

#### 動作
- **新規作成時のみ**（`_isEditing == false`）、選択された日付にすでにシフトがある従業員を「Assign To」ドロップダウンの候補から除外する
- 編集時は全従業員を表示する（既存のReact動作と一致）

#### 実装方針

1. **state変数を追加**
   ```dart
   Set<String> _userIdsWithShift = {};
   Set<String> _employeeIdsWithShift = {};
   bool _isLoadingExistingShifts = false;
   ```

2. **日付の既存シフトを取得するメソッドを追加**
   ```dart
   Future<void> _loadExistingShiftsForDate() async {
     if (_isEditing) return; // 編集時はスキップ
     setState(() => _isLoadingExistingShifts = true);
     try {
       final profile = await ref.read(profileProvider.future);
       if (profile?.organizationId == null) return;
       final repository = ref.read(shiftRepositoryProvider);
       final shifts = await repository.getShiftsForOrganization(
         organizationId: profile!.organizationId!,
         startDate: _date,
         endDate: _date,
       );
       if (!mounted) return;
       setState(() {
         _userIdsWithShift = shifts
             .where((s) => s.userId != null)
             .map((s) => s.userId!)
             .toSet();
         _employeeIdsWithShift = shifts
             .where((s) => s.employeeId != null)
             .map((s) => s.employeeId!)
             .toSet();
       });
     } catch (_) {
       // フィルタリング失敗時は全員表示（フォールバック）
       setState(() {
         _userIdsWithShift = {};
         _employeeIdsWithShift = {};
       });
     } finally {
       if (mounted) setState(() => _isLoadingExistingShifts = false);
     }
   }
   ```

3. **呼び出しタイミング**
   - `initState()` の末尾で `_loadExistingShiftsForDate()` を呼ぶ
   - 日付変更時（DatePickerの `onTap` コールバック内）に再呼び出し：
     ```dart
     if (date != null) {
       setState(() => _date = date);
       _loadExistingShiftsForDate();
     }
     ```

4. **ドロップダウンのフィルタリング**
   - `employeesAsync.when(data: (employees) => ...)` 内でフィルタを適用：
     ```dart
     final filteredEmployees = _isEditing
         ? employees
         : employees.where((e) =>
             !_userIdsWithShift.contains(e.id) &&
             !(e.employeeId != null &&
               _employeeIdsWithShift.contains(e.employeeId))
           ).toList();
     ```
   - DropdownButtonFormField の `items` に `filteredEmployees` を使用

5. **ローディング中のUX**
   - `_isLoadingExistingShifts == true` の間、ドロップダウンの代わりに `LinearProgressIndicator` を表示（既存のloading/errorハンドリングに合わせる）

---

### 機能2: Repeatシフト作成時の重複検出ダイアログ

#### 動作
- Repeatシフト保存時、生成される全日程について従業員の既存シフトとの重複をチェックする
- 重複が見つかった場合、React版と同等の選択肢を持つダイアログを表示する
- **これはフロントエンド側の事前チェック（保存前）**

#### ダイアログ仕様

**タイトル:** "Overlapping Shifts Found"

**本文:**
```
{従業員名} already has shifts on {N} of the {M} dates:
```

**重複日のリスト表示:**
- 各重複日の日付と既存シフトの時間帯を表示
- 最大10件表示、超過分は "...and X more" で省略
- org timezone で表示

**アクションボタン（3つ）:**

| ボタン | 動作 | スタイル |
|--------|------|----------|
| **Cancel** | フォームに戻る。何も作成しない | TextButton |
| **Skip Conflicts** | 重複のある日をスキップし、重複のない日のみシフトを作成する | OutlinedButton |
| **Create All** | 重複を無視して全日程のシフトを作成する | FilledButton（amber） |

※ 全日程が重複する場合は「Skip Conflicts」を非表示にする（スキップすると0件作成になるため）

#### 実装方針

1. **重複チェック用メソッドを追加**
   ```dart
   /// Repeat シフトの各日程について重複を一括チェック
   /// 戻り値: { date: [overlapping shifts] } のマップ
   Future<Map<DateTime, List<Shift>>> _checkRepeatOverlaps({
     required String userId,
     required List<DateTime> dates,
     required TimeOfDay startTime,
     required TimeOfDay endTime,
   }) async {
     final repository = ref.read(shiftRepositoryProvider);
     final overlaps = <DateTime, List<Shift>>{};

     for (final date in dates) {
       final shifts = await repository.getShiftsForProfile(
         userId: userId,
         startDate: date,
         endDate: date,
         isPublished: null,
       );

       final newStart = DateTime(date.year, date.month, date.day,
           startTime.hour, startTime.minute);
       final newEnd = DateTime(date.year, date.month, date.day,
           endTime.hour, endTime.minute);
       // 日跨ぎ対応
       final adjustedEnd = newEnd.isBefore(newStart)
           ? newEnd.add(const Duration(days: 1))
           : newEnd;

       final conflicting = shifts.where((s) {
         return newStart.millisecondsSinceEpoch < s.endTime.millisecondsSinceEpoch &&
                adjustedEnd.millisecondsSinceEpoch > s.startTime.millisecondsSinceEpoch;
       }).toList();

       if (conflicting.isNotEmpty) {
         overlaps[date] = conflicting;
       }
     }
     return overlaps;
   }
   ```

2. **ダイアログ表示メソッド**
   ```dart
   /// 戻り値: 'cancel' | 'skip' | 'create_all'
   Future<String?> _showRepeatOverlapDialog({
     required Map<DateTime, List<Shift>> overlaps,
     required int totalDates,
   }) {
     // ... AlertDialog を構築して表示
   }
   ```

3. **_save() のRepeatパス（Path B）を修正**

   現在の `_save()` 内のRepeatシフト作成パス（lines 2165-2184付近）を以下のように変更：

   ```dart
   // Repeatシフト作成パス
   if (!_isEditing && _repeatType != 'none' && _selectedDays.isNotEmpty) {
     final dates = _generatePreviewDates();
     if (dates.isEmpty) return;

     // 従業員が割り当てられている場合、重複チェック
     if (_userId != null && !_isPending) {
       setState(() => _isSaving = true);
       final overlaps = await _checkRepeatOverlaps(
         userId: _userId!,
         dates: dates,
         startTime: _startTime,
         endTime: _endTime,
       );
       setState(() => _isSaving = false);

       if (overlaps.isNotEmpty) {
         final choice = await _showRepeatOverlapDialog(
           overlaps: overlaps,
           totalDates: dates.length,
         );

         if (choice == null || choice == 'cancel') return;

         if (choice == 'skip') {
           final conflictDates = overlaps.keys.toSet();
           final safeDates = dates.where((d) =>
             !conflictDates.any((cd) =>
               cd.year == d.year && cd.month == d.month && cd.day == d.day
             )
           ).toList();

           if (safeDates.isEmpty) {
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('All dates have conflicts. No shifts created.')),
               );
             }
             return;
           }

           // safeDatesのみで作成（下記「バックエンド連携」参照）
         }

         // choice == 'create_all' → そのまま続行
       }
     }

     // 既存の bulk 作成ロジック（onSave コールバック）
     setState(() => _isSaving = true);
     // ... 既存の保存処理
   }
   ```

---

### 機能3: Unavailability / PTO コンフリクト警告ダイアログ

#### 動作概要
- **事後チェック方式** — バックエンドAPIがシフト作成時に Unavailability / PTO / Closed Day をチェックし、レスポンスに `warnings` を含めて返す
- Flutter側はAPIレスポンスの `warnings` と `conflicting_shift_ids` を解析し、警告ダイアログを表示する
- 単発シフト・Repeatシフトの両方に適用

#### React側の参考実装

**APIレスポンス形式:**

```typescript
// 単発シフト POST /api/shifts
{
  success: true,
  data: { id, user_id, start_time, ... } | null,
  skipped?: boolean,                    // block設定時にスキップされた場合 true
  warnings?: ShiftWarning[]
}

// Bulk POST /api/shifts/bulk
{
  success: true,
  data: Array<{ id, user_id, start_time, ... }>,
  message: string,
  warnings?: ShiftWarning[],
  conflicting_shift_ids?: string[]     // 警告付きで作成されたシフトのID
}
```

**ShiftWarning 型:**
```typescript
interface ShiftWarning {
  type: "unavailability_conflict"          // 警告のみ（作成済み）
      | "skipped_due_to_unavailability"    // ブロック設定によりスキップ
      | "pto_conflict"                     // PTO衝突（作成済み）
      | "closed_day_annotation";           // 休業日
  message: string;
  details: UnavailabilityConflict | PTOConflict;
}

interface UnavailabilityConflict {
  unavailability_id: string;
  user_id: string;
  user_name: string;
  title: string | null;
  start_date: string;
  end_date: string;
  start_time: string | null;   // HH:mm（部分的Unavailability）
  end_time: string | null;
  is_all_day: boolean;
  shift_date: string;
}

interface PTOConflict {
  pto_id: string;
  user_id: string;
  user_name: string;
  pto_type: string;            // vacation, sick, personal, etc.
  status: string;              // pending, approved
  start_date: string;
  end_date: string;
  total_days: number;
  reason: string | null;
  shift_date: string;
}
```

**組織設定 `block_shifts_during_unavailability`:**
- `true` → Unavailability/PTO衝突のあるシフトは**作成されない**（`skipped_due_to_unavailability`）
- `false` → シフトは**作成されるが警告が返る**（`unavailability_conflict`, `pto_conflict`）

#### Flutter側の実装方針

##### 3-1. ShiftWarning モデルの追加

```dart
// lib/data/models/shift_warning.dart（新規作成）

@freezed
class ShiftWarning with _$ShiftWarning {
  const factory ShiftWarning({
    required String type,      // 'unavailability_conflict', 'skipped_due_to_unavailability',
                               // 'pto_conflict', 'closed_day_annotation'
    required String message,
    required Map<String, dynamic> details,
  }) = _ShiftWarning;

  factory ShiftWarning.fromJson(Map<String, dynamic> json) =>
      _$ShiftWarningFromJson(json);
}

// 便利ゲッター
extension ShiftWarningX on ShiftWarning {
  bool get isSkipped => type == 'skipped_due_to_unavailability';
  bool get isPtoConflict => type == 'pto_conflict';
  bool get isUnavailabilityConflict => type == 'unavailability_conflict';
  bool get isClosedDay => type == 'closed_day_annotation';

  String get userName => details['user_name'] as String? ?? '';
  String get shiftDate => details['shift_date'] as String? ?? '';
}
```

##### 3-2. API レスポンスの解析を拡張

現在の `ShiftApiService.createShift()` / `createShiftsBulk()` のレスポンス解析を拡張し、`warnings` と `conflicting_shift_ids` をパースする。

```dart
// createShift の戻り値を拡張
class ShiftCreateResult {
  final Shift? shift;
  final bool skipped;
  final List<ShiftWarning> warnings;

  ShiftCreateResult({this.shift, this.skipped = false, this.warnings = const []});
}

// createShiftsBulk の戻り値を拡張
class ShiftBulkCreateResult {
  final List<Shift> shifts;
  final List<ShiftWarning> warnings;
  final List<String> conflictingShiftIds;
  final String? message;

  ShiftBulkCreateResult({
    this.shifts = const [],
    this.warnings = const [],
    this.conflictingShiftIds = const [],
    this.message,
  });
}
```

##### 3-3. 警告ダイアログの実装

**ダイアログ仕様:**

**タイトル:**
- スキップが含まれる場合: "Unavailability Conflicts"
- 警告のみの場合: "Unavailability Warnings"

**ヘッダーバッジ:**
- `{N} Created` （緑バッジ） — 作成されたシフト数
- `{N} Skipped` （黄バッジ） — block設定でスキップされた数
- `{N} Warnings` （オレンジバッジ） — 警告付きで作成された数

**警告リスト（色分け）:**

| 警告タイプ | 背景色 | アイコン | バッジ |
|-----------|--------|---------|--------|
| `skipped_due_to_unavailability` | 黄色 | Ban | "Skipped" |
| `pto_conflict` | 青色 | AlertTriangle | "PTO Approved" or "PTO Pending" |
| `unavailability_conflict` | オレンジ | Info | "Created with conflict" |
| `closed_day_annotation` | 赤色 | AlertTriangle | "Closed Day" |

**各警告の表示内容:**

PTO の場合:
```
{user_name}
{pto_type} ({start_date} - {end_date}, {total_days} days)
Reason: {reason}                    ← reason がある場合のみ
[PTO Approved] or [PTO Pending]     ← ステータスバッジ
```

Unavailability の場合:
```
{user_name}
{shift_date} - {title}             ← title がある場合
Unavailable: {start_time} - {end_time}  ← all_day でない場合のみ
[Skipped] or [Created with conflict]
```

**アクションボタン（3つ）:**

| ボタン | 表示条件 | 動作 | スタイル |
|--------|---------|------|----------|
| **Undo (Delete {N} shifts)** | 作成済みシフトが1つ以上ある | 作成された全シフトを一括削除して閉じる | TextButton (destructive) |
| **Skip Conflicts (Remove {X}, Keep {Y})** | `conflictingShiftIds` が1つ以上あり、かつ全シフトではない | 衝突シフトのみ削除し、残りを保持 | OutlinedButton |
| **Keep All** / **OK** | 常に表示 | block設定の場合は "OK"、それ以外は "Keep All"。ダイアログを閉じて全シフト保持 | FilledButton |

##### 3-4. _save() フローへの統合

**単発シフト作成後:**
```dart
// 既存の保存コールバックを拡張
// onSave が ShiftCreateResult を返すようにする
final result = await widget.onSave(shiftData);

if (result.skipped) {
  // block設定でスキップされた
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Shift skipped due to unavailability')),
  );
}

if (result.warnings.isNotEmpty) {
  await _showUnavailabilityWarningDialog(
    warnings: result.warnings,
    createdShiftIds: result.shift != null ? [result.shift!.id] : [],
    conflictingShiftIds: [],  // 単発なので常に空 or [shift.id]
    createdCount: result.shift != null ? 1 : 0,
    skippedCount: result.skipped ? 1 : 0,
  );
}
```

**Repeatシフト作成後:**
```dart
// bulk作成の結果から warnings を取得
final bulkResult = await widget.onSave(bulkShiftData);

if (bulkResult.warnings.isNotEmpty) {
  await _showUnavailabilityWarningDialog(
    warnings: bulkResult.warnings,
    createdShiftIds: bulkResult.shifts.map((s) => s.id).toList(),
    conflictingShiftIds: bulkResult.conflictingShiftIds,
    createdCount: bulkResult.shifts.length,
    skippedCount: /* warningsからskippedをカウント */,
  );
}
```

##### 3-5. Undo / Skip Conflicts のアクション

```dart
// Undo: 全作成シフトを削除
Future<void> _handleUndoCreatedShifts(List<String> shiftIds) async {
  final shiftApi = ref.read(shiftApiServiceProvider);
  await shiftApi.deleteShiftsBulk(shiftIds);
  // SnackBar: "{N} shift(s) removed"
}

// Skip Conflicts: 衝突シフトのみ削除
Future<void> _handleSkipConflictingShifts(
  List<String> conflictingIds,
  int totalCreated,
) async {
  final shiftApi = ref.read(shiftApiServiceProvider);
  await shiftApi.deleteShiftsBulk(conflictingIds);
  final kept = totalCreated - conflictingIds.length;
  // SnackBar: "{N} conflicting shift(s) removed, {kept} kept"
}
```

##### 3-6. state変数の追加

```dart
// Unavailability/PTO 警告用
List<ShiftWarning> _unavailabilityWarnings = [];
int _createdShiftCount = 0;
int _skippedShiftCount = 0;
List<String> _createdShiftIds = [];
List<String> _conflictingShiftIds = [];
bool _undoingShifts = false;
bool _skippingConflicts = false;
```

---

## 処理フロー全体図

```
ユーザーが Save をタップ
│
├─ 単発シフト
│  ├─ 1. 既存の _checkOverlappingShifts() → 重複警告（Cancel / Create Anyway）
│  ├─ 2. API POST /api/shifts 実行
│  └─ 3. response.warnings があれば → Unavailability/PTO 警告ダイアログ（機能3）
│
└─ Repeat シフト
   ├─ 1. _checkRepeatOverlaps() → 重複警告（Cancel / Skip / Create All）（機能2）
   ├─ 2. API POST /api/shifts/bulk 実行（skip選択時は除外済み日付で）
   └─ 3. response.warnings があれば → Unavailability/PTO 警告ダイアログ（機能3）
```

---

## バックエンド連携

### Skip Conflicts の実現方式（機能2: Repeat重複）

重複日をスキップする方法として2つの選択肢がある：

**方式A: `skip_dates` をrepeat_ruleに追加**
- `repeat_rule` に `skip_dates: ['2024-06-03', '2024-06-10']` を追加
- バックエンド側でスキップ処理が必要
- バックエンドの変更が必要

**方式B: フロントエンドで日付を制御（推奨）**
- 重複のない日付のみを使って repeat_rule を再構築、または `bulk: true` のまま日付リストを送信
- 既存のバックエンドAPIをそのまま利用可能
- **現行のbulk作成APIが `repeat_rule` ベースのため、skip対象日を除外した個別日付での一括作成が可能か確認が必要**

→ まずは方式Bで実装を試み、バックエンドAPIの制約があれば方式Aに切り替える。

### Unavailability/PTO 警告（機能3）

- バックエンドは既に `warnings` と `conflicting_shift_ids` をレスポンスに含む実装済み
- Flutter側はAPIレスポンスのパースを拡張するだけで対応可能（バックエンド変更不要）
- Undo / Skip Conflicts のシフト削除は既存の bulk delete API (`POST /api/shifts/bulk` with `action: "delete"`) を使用

---

## 対象外（スコープ外）

- `add_shift_dialog.dart`（タイムシート用の手動シフト追加）は今回の対象外
- 編集モードでの重複フィルタリングは行わない（React版と同一仕様）

---

## テスト観点

### 機能1: 単発シフト作成時の従業員フィルタリング
- 日付Aに従業員Xのシフトが存在する状態で、日付Aの新規シフト作成時、従業員Xがドロップダウンに表示されないこと
- 日付を変更すると候補が再読み込みされること
- 編集モードでは全従業員が表示されること
- APIエラー時はフォールバックとして全従業員が表示されること

### 機能2: Repeatシフト作成時の重複検出
- 5日中2日に重複がある場合、ダイアログに2日分の重複が表示されること
- 「Cancel」→ シフト未作成でフォームに戻ること
- 「Skip Conflicts」→ 重複のない3日分のみ作成されること
- 「Create All」→ 5日分すべて作成されること
- 全日重複の場合「Skip Conflicts」ボタンが非表示であること
- 未割り当て（Unassigned）のRepeatシフトは重複チェックをスキップすること

### 機能3: Unavailability / PTO コンフリクト警告
- Unavailabilityのある日にシフト作成 → `block_shifts_during_unavailability = true` の場合スキップされダイアログに "Skipped" 表示
- Unavailabilityのある日にシフト作成 → `block_shifts_during_unavailability = false` の場合作成されダイアログに "Created with conflict" 表示
- PTO（approved）のある日にシフト作成 → 警告ダイアログに PTO 情報が表示されること
- PTO（pending）のある日にシフト作成 → 警告ダイアログに PTO Pending が表示されること
- 「Undo」→ 作成された全シフトが削除されること
- 「Skip Conflicts」→ conflicting_shift_ids のシフトのみ削除、残りは保持されること
- 「Keep All」→ 全シフトがそのまま保持されること
- 警告がない場合はダイアログが表示されずフォームが閉じること
- Repeat + Unavailability の組み合わせ（機能2のSkip後に機能3の警告が出るケース）

### pending従業員
- pending従業員は `employee_id` のみで照合されること（`user_id` がないため）
- Repeatの重複チェックはpending従業員ではスキップされること（既存仕様の踏襲）
- Unavailability/PTO チェックはバックエンド依存のため、pending従業員でも警告が返れば表示する
