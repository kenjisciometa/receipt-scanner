# 汎用的マルチ国税金抽出システム - 修正要件定義書

## 1. プロジェクト概要

### 1.1 目的
特定の国・言語・店舗に依存しない、真に汎用的な税金breakdown抽出システムの実装。
既存のハードコーディング依存を排除し、自己学習・適応型のシステムを構築する。

### 1.2 現状の問題点
- **特定店舗依存**: Walmart, Target等のハードコード
- **言語固定**: 特定税金用語（MwSt, VAT等）への過度依存
- **パターン固定**: 柔軟性のないregexパターン
- **スケーラビリティ不足**: 新規国・形式への適応困難

### 1.3 期待効果
- 完全汎用性（任意の国・言語・レシート形式対応）
- 自動学習・適応能力
- 保守性・拡張性の大幅向上
- 抽出精度と信頼性の向上

## 2. 技術要件

### 2.1 アーキテクチャ設計

#### 2.1.1 レイヤー構造
```
┌─────────────────────────────────────────┐
│          API Layer (統合インターface)       │
├─────────────────────────────────────────┤
│       Orchestration Layer (協調制御)      │
├─────────────────────────────────────────┤
│ ┌─────────────┐ ┌────────────────────────┐ │
│ │ Pattern     │ │ Structure              │ │
│ │ Learning    │ │ Analysis               │ │
│ │ Engine      │ │ Engine                 │ │
│ └─────────────┘ └────────────────────────┘ │
├─────────────────────────────────────────┤
│ ┌─────────────┐ ┌────────────────────────┐ │
│ │ Currency    │ │ Statistical            │ │
│ │ Detection   │ │ Validation             │ │
│ │ Engine      │ │ Engine                 │ │
│ └─────────────┘ └────────────────────────┘ │
├─────────────────────────────────────────┤
│      Foundation Layer (基盤コンポーネント)   │
└─────────────────────────────────────────┘
```

#### 2.1.2 コア設計原則
- **Language Agnostic**: 言語固有要素の最小化
- **Adaptive Learning**: 継続的パターン学習
- **Multi-Layer Validation**: 複数検証手法の組み合わせ
- **Fail-Safe Design**: 段階的フォールバック機能

### 2.2 主要コンポーネント

#### 2.2.1 構造的パターン認識エンジン
```typescript
interface StructuralAnalysisEngine {
  // 数値的特徴による税金候補検出
  detectNumericalSignatures(textLines: string[]): NumericalSignature[];
  
  // 空間的配置による構造解析
  analyzeSpatialRelationships(signatures: NumericalSignature[]): SpatialStructure[];
  
  // 文書階層による税金セクション特定
  identifyDocumentStructure(textLines: string[]): DocumentStructure;
}
```

**実装要件:**
- パーセンテージ(%)と金額の組み合わせ自動検出
- subtotal→tax→total の論理的流れ認識
- 行間の空間的関係性分析
- セクション境界の自動判定

#### 2.2.2 汎用的通貨検出システム
```typescript
interface UniversalCurrencyDetector {
  // 動的通貨記号認識
  detectCurrencySymbols(text: string): CurrencyDetectionResult;
  
  // 数値形式推論
  inferNumberFormat(amounts: string[]): NumberFormatProfile;
  
  // 地域慣習の動的推論
  inferRegionalConventions(context: AnalysisContext): RegionalProfile;
}
```

**実装要件:**
- Unicode通貨記号の包括的認識
- 小数点記号（. vs ,）の動的判定
- 桁区切り文字の自動認識
- 通貨位置（前置/後置）の推論

#### 2.2.3 機械学習型パターン学習エンジン
```typescript
interface PatternLearningEngine {
  // 成功パターンからの特徴抽出
  extractSuccessFeatures(results: ExtractionHistory[]): FeatureSet;
  
  // 新規パターンの動的生成
  generateAdaptivePatterns(features: FeatureSet): AdaptivePattern[];
  
  // パターン効果の継続評価
  evaluatePatternEffectiveness(patterns: AdaptivePattern[]): EvaluationReport;
}
```

**実装要件:**
- 成功した抽出事例からの特徴学習
- 失敗パターンの回避ルール生成
- 新規レシート形式への適応アルゴリズム
- パターン効果の定量的評価

#### 2.2.4 階層的構造分析システム
```typescript
interface HierarchicalStructureAnalyzer {
  // 文書レベル構造セグメンテーション
  segmentDocument(textLines: string[]): DocumentSegments;
  
  // 税金関連セクションの特定
  identifyTaxRelevantSections(segments: DocumentSegments): TaxSection[];
  
  // 詳細税金エントリ解析
  analyzeDetailedTaxEntries(sections: TaxSection[]): TaxEntry[];
}
```

**実装要件:**
- レシート構造の階層的理解
- ヘッダー・本文・フッターの自動分離
- 税金関連情報の集中領域特定
- 行レベルでの詳細税金情報抽出

#### 2.2.5 統計的妥当性検証システム
```typescript
interface StatisticalValidationEngine {
  // 税率の統計的妥当性検証
  validateTaxRateReasonableness(rates: number[]): ValidationResult;
  
  // 数学的整合性の多層検証
  verifyMathematicalConsistency(breakdown: TaxBreakdown): ConsistencyReport;
  
  // 異常値・外れ値の検出
  detectStatisticalAnomalies(extraction: TaxExtraction): AnomalyReport;
}
```

**実装要件:**
- 世界各国の一般的税率データベース
- subtotal + tax = total の数学的検証
- 統計的外れ値の自動検出
- 多段階信頼度スコアリング

### 2.3 データ構造設計

#### 2.3.1 汎用的税金抽出結果
```typescript
interface UniversalTaxExtraction {
  // 検出された税金エントリ
  taxEntries: UniversalTaxEntry[];
  
  // 抽出メタデータ
  extractionMetadata: ExtractionMetadata;
  
  // 信頼度情報
  confidenceProfile: ConfidenceProfile;
  
  // 学習データ
  learningData: LearningData;
}

interface UniversalTaxEntry {
  // 税率（パーセンテージ）
  rate: number;
  
  // 税額
  taxAmount: number;
  
  // 課税対象額
  taxableAmount?: number;
  
  // 検出方法
  detectionMethod: DetectionMethod;
  
  // 信頼度スコア
  confidenceScore: number;
  
  // 位置情報
  spatialLocation: SpatialLocation;
}
```

#### 2.3.2 学習・適応データ
```typescript
interface LearningData {
  // パターン特徴
  patternFeatures: FeatureVector[];
  
  // 成功要因
  successFactors: SuccessFactor[];
  
  // 改善候補
  improvementCandidates: ImprovementCandidate[];
  
  // 適応履歴
  adaptationHistory: AdaptationRecord[];
}
```

## 3. 実装計画

### 3.1 フェーズ1: 基盤インフラ構築
**期間**: 1-2週間
**成果物**:
- 汎用的データ構造定義
- 基本的構造解析エンジン
- 通貨検出システム基礎版

**主要タスク**:
- ハードコーディング要素の完全除去
- 言語非依存の数値パターン検出実装
- Unicode通貨記号認識システム構築

### 3.2 フェーズ2: 構造的分析エンジン実装
**期間**: 2-3週間
**成果物**:
- 階層的文書構造分析
- 空間的関係認識システム
- 税金セクション自動特定

**主要タスク**:
- 文書セグメンテーションアルゴリズム
- 空間配置解析エンジン
- 論理的構造認識システム

### 3.3 フェーズ3: 学習・適応機能実装
**期間**: 3-4週間
**成果物**:
- パターン学習エンジン
- 適応的パターン生成
- 継続的改良システム

**主要タスク**:
- 特徴抽出アルゴリズム実装
- 動的パターン生成システム
- 効果測定・改良サイクル

### 3.4 フェーズ4: 統合・検証
**期間**: 1-2週間
**成果物**:
- 統合システム完成版
- 包括的テストスイート
- パフォーマンス最適化

**主要タスク**:
- コンポーネント統合
- 多国籍レシートでの包括テスト
- 性能チューニング

## 4. 成功基準・KPI

### 4.1 機能要件達成指標
- **汎用性**: 15ヶ国以上のレシート形式対応
- **精度**: 税金抽出精度95%以上
- **適応性**: 新規形式への24時間以内自動適応
- **性能**: 処理時間50ms以内

### 4.2 技術品質指標
- **保守性**: ハードコーディング完全排除
- **拡張性**: 新規国追加時のコード変更最小化
- **信頼性**: 検証多重化による信頼度向上
- **学習効果**: 継続使用による精度自動向上

### 4.3 ビジネス価値指標
- **運用コスト削減**: パターンメンテナンス作業90%削減
- **対応国拡大**: 新規市場参入時間75%短縮
- **顧客満足度**: レシート処理成功率向上
- **競合優位性**: 汎用性による差別化

## 5. リスク管理

### 5.1 技術リスク
- **複雑性増大**: 過度な汎用化による性能低下
- **学習データ不足**: 初期段階での精度低下
- **計算コスト**: 機械学習処理による負荷増大

### 5.2 緩和策
- 段階的実装による複雑性制御
- 既存成功パターンの初期学習データ化
- 効率的アルゴリズム選択とキャッシング

### 5.3 品質保証
- 多国籍テストデータセット構築
- 継続的インテグレーション環境
- A/Bテストによる段階的デプロイ

## 6. 付録

### 6.1 参考技術
- Natural Language Processing (NLP)
- Pattern Recognition
- Machine Learning (特徴学習)
- Statistical Analysis
- Computer Vision (空間解析)

### 6.2 実装技術スタック
- **言語**: TypeScript
- **分析**: 統計ライブラリ
- **学習**: 軽量ML フレームワーク
- **テスト**: 包括的テストフレームワーク

### 6.3 文書管理
- **更新頻度**: 開発進捗に応じて週次更新
- **レビュー**: 各フェーズ完了時の要件適合性確認
- **承認**: ステークホルダー承認プロセス

---

**文書作成日**: 2025-01-07  
**作成者**: Claude Code Assistant  
**承認者**: [要承認]  
**次回レビュー予定**: [要設定]