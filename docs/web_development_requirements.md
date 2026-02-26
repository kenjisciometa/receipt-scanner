# Web版レシートOCR＋ML学習システム 開発要件定義書

## 1. プロジェクト概要

### 1.1 目的
- Flutter実装を参考にしたNext.js Web版レシートOCRシステムの開発
- 機械学習用データ収集・ラベリングシステムの構築
- 高精度抽出モデルの開発・訓練・API化
- FlutterとWebの共通パイプライン実現

### 1.2 成果物
- Next.js Web アプリケーション
- OCR + 抽出結果表示UI
- 手動修正・検証システム
- 機械学習パイプライン
- 高精度抽出API
- 共通データフォーマット

---

## 2. Flutterアプリ分析結果

### 2.1 既存実装の構造
```
├── OCR Service (ML Kit)
│   ├── 画像前処理
│   ├── テキスト認識
│   └── textLines生成 (bounding box付き)
├── Extraction Service
│   ├── ルールベース抽出
│   ├── 多言語対応 (EN/FI/SV/FR/DE/IT/ES)
│   ├── 金額整合性チェック
│   └── 信頼度スコア算出
├── Training Data Collector
│   ├── raw JSONデータ保存
│   ├── verified JSONデータ保存  
│   ├── 特徴量抽出
│   └── ラベル生成
└── Preview UI
    ├── OCR結果表示
    ├── 抽出結果編集
    └── データ保存
```

### 2.2 重要な実装パターン
- **非同期処理**: OCR→抽出の段階的処理
- **信頼度管理**: 0.7未満でneeds_verification
- **データ標準化**: JSON形式でのI/O統一
- **多言語対応**: キーワードベース抽出
- **整合性チェック**: subtotal + tax ≈ total

---

## 3. Web版システム要件

### 3.1 技術スタック
```yaml
Framework: Next.js 14+ (App Router)
Language: TypeScript
Styling: Tailwind CSS
State: Zustand / React Query
OCR: Google Cloud Vision API
Database: PostgreSQL + Prisma
Storage: AWS S3 / Google Cloud Storage
ML: Python + FastAPI
Deployment: Docker + Cloud Run
```

### 3.2 システム構成
```
Web UI (Next.js)
  ↓
Backend API (Next.js API Routes)
  ↓
OCR Service (Google Cloud Vision)
  ↓
Extraction Service (TypeScript Port)
  ↓
Database (PostgreSQL)
  ↓
ML Pipeline (Python + FastAPI)
  ↓
Training Data Storage (Cloud Storage)
```

---

## 4. Receipt/Invoice自動区別要件（Flutterベース）

### 4.1 文書タイプ分類システム

#### 4.1.1 DocumentTypeClassifier
```typescript
interface DocumentTypeResult {
  documentType: 'receipt' | 'invoice' | 'unknown';
  confidence: number;        // 0.0-1.0
  reason: string;           // 分類理由
  receiptScore: number;     // レシートスコア
  invoiceScore: number;     // 請求書スコア
}

// 分類アルゴリズム（Flutter実装準拠）
class DocumentTypeClassifier {
  static classify(textLines: TextLine[], language?: string): DocumentTypeResult {
    let receiptScore = 0.0;
    let invoiceScore = 0.0;
    
    // 1. キーワードベース分類（高重要度: 2.0倍）
    receiptScore += checkReceiptKeywords(textLines) * 2.0;
    invoiceScore += checkInvoiceKeywords(textLines) * 2.0;
    
    // 2. 構造的特徴分析（中重要度: 1.5倍）
    receiptScore += checkReceiptStructure(textLines) * 1.5;
    invoiceScore += checkInvoiceStructure(textLines) * 1.5;
    
    // 3. 金額・支払いパターン（標準重要度: 1.0倍）
    receiptScore += checkReceiptPaymentPattern(textLines);
    invoiceScore += checkInvoicePaymentPattern(textLines);
    
    // 判定ロジック
    const scoreDiff = Math.abs(receiptScore - invoiceScore);
    const totalScore = receiptScore + invoiceScore;
    const confidence = totalScore > 0 ? (scoreDiff / totalScore) : 0.0;
    
    let documentType: string;
    if (receiptScore > invoiceScore + 1.0) {
      documentType = 'receipt';
    } else if (invoiceScore > receiptScore + 1.0) {
      documentType = 'invoice';
    } else {
      documentType = 'unknown';
    }
    
    return { documentType, confidence, receiptScore, invoiceScore };
  }
}
```

#### 4.1.2 キーワード定義（多言語対応）
```typescript
// Receipt特有キーワード
const RECEIPT_KEYWORDS = {
  'en': ['receipt', 'thank you', 'customer copy', 'paid', 'payment received'],
  'fi': ['kuitti', 'kiitos', 'asiakasnäyte', 'maksettu', 'maksu vastaanotettu'],
  'sv': ['kvitto', 'tack', 'kundkopia', 'betalad', 'betalning mottagen'],
  'fr': ['reçu', 'merci', 'copie client', 'payé', 'paiement reçu'],
  'de': ['quittung', 'danke', 'kundenbeleg', 'bezahlt', 'zahlung erhalten'],
  'it': ['ricevuta', 'grazie', 'copia cliente', 'pagato', 'pagamento ricevuto'],
  'es': ['recibo', 'gracias', 'copia del cliente', 'pagado', 'pago recibido']
};

// Invoice特有キーワード
const INVOICE_KEYWORDS = {
  'en': ['invoice', 'bill to', 'due date', 'payment terms', 'net 30', 'billing address'],
  'fi': ['lasku', 'laskutettava', 'eräpäivä', 'maksuehto', 'maksuaika', 'laskutusosoite'],
  'sv': ['faktura', 'fakturera till', 'förfallodatum', 'betalningsvillkor'],
  'fr': ['facture', 'facturer à', 'date d\'échéance', 'conditions de paiement'],
  'de': ['rechnung', 'rechnungsempfänger', 'fälligkeitsdatum', 'zahlungsbedingungen'],
  'it': ['fattura', 'fatturare a', 'data di scadenza', 'termini di pagamento'],
  'es': ['factura', 'facturar a', 'fecha de vencimiento', 'términos de pago']
};
```

### 4.2 フィールド抽出の差別化

#### 4.2.1 Receipt特有フィールド
```typescript
interface ReceiptData {
  document_type: 'receipt';
  payment_method: 'cash' | 'card' | 'mobile' | 'contactless';
  payment_status: 'paid' | 'completed';
  customer_copy: boolean;
  transaction_id?: string;
}
```

#### 4.2.2 Invoice特有フィールド
```typescript
interface InvoiceData {
  document_type: 'invoice';
  due_date: string;           // ISO 8601
  payment_terms: string;      // 'Net 30', 'Net 60', etc.
  bill_to: {
    name: string;
    address: string;
  };
  invoice_number: string;
  payment_status: 'unpaid' | 'pending' | 'overdue';
  billing_address?: string;
}
```

### 4.3 データベーススキーマ拡張
```sql
-- 文書タイプ分類結果
ALTER TABLE extraction_results ADD COLUMN document_type VARCHAR(20);
ALTER TABLE extraction_results ADD COLUMN document_type_confidence FLOAT;
ALTER TABLE extraction_results ADD COLUMN document_type_reason TEXT;
ALTER TABLE extraction_results ADD COLUMN receipt_score FLOAT;
ALTER TABLE extraction_results ADD COLUMN invoice_score FLOAT;

-- Invoice特有フィールド
ALTER TABLE extraction_results ADD COLUMN due_date DATE;
ALTER TABLE extraction_results ADD COLUMN payment_terms VARCHAR(50);
ALTER TABLE extraction_results ADD COLUMN bill_to_name VARCHAR(255);
ALTER TABLE extraction_results ADD COLUMN bill_to_address TEXT;
ALTER TABLE extraction_results ADD COLUMN billing_address TEXT;

-- Receipt特有フィールド  
ALTER TABLE extraction_results ADD COLUMN transaction_id VARCHAR(100);
ALTER TABLE extraction_results ADD COLUMN customer_copy BOOLEAN DEFAULT FALSE;
```

---

## 5. 機能要件詳細

### 4.1 Phase 1: 基本OCRシステム

#### 4.1.1 画像アップロード
- **要件**: ドラッグ&ドロップ、ファイル選択
- **対応形式**: JPEG, PNG, PDF
- **制限**: 10MB以下、最大解像度4000x4000
- **参考**: Flutter camera_screen.dart実装

#### 4.1.2 OCR処理
```typescript
interface OCRResult {
  text: string;                    // 全認識テキスト
  textLines: TextLine[];          // 行ごとの結果
  confidence: number;             // 全体信頼度
  detected_language: string;      // 検出言語
  processing_time: number;        // 処理時間(ms)
  success: boolean;               // 処理成功フラグ
}

interface TextLine {
  text: string;
  confidence: number;
  boundingBox: [number, number, number, number]; // [x, y, w, h]
}
```

#### 4.1.3 抽出処理
```typescript
interface ExtractionResult {
  merchant_name: string | null;
  date: string | null;           // ISO 8601
  currency: string;              // EUR, USD, etc.
  subtotal: number | null;
  tax_breakdown: TaxBreakdown[];
  tax_total: number | null;
  total: number;                 // 必須
  receipt_number: string | null;
  payment_method: string | null;
  confidence: number;
  status: ReceiptStatus;
  needs_verification: boolean;
  extracted_items: ReceiptItem[];
}
```

#### 4.1.4 結果表示UI
- **OCR結果**: 元画像 + bounding box overlay
- **抽出結果**: フォーム形式で編集可能
- **信頼度**: 色分け表示（緑>0.8, 黄0.5-0.8, 赤<0.5）
- **参考**: Flutter preview_screen.dart

### 4.2 Phase 2: データ収集・管理システム

#### 4.2.0 機械学習用JSON出力要件（Flutterベース）

##### **A. Raw Training Data自動出力**
```typescript
// 自動抽出結果をJSONファイルに保存（data/training/raw/）
interface RawTrainingData {
  receipt_id: string;
  timestamp: string;
  is_verified: false;           // Raw データは未検証
  text_lines: TextLineWithLabels[];
  extraction_result: ExtractionResult;
  metadata: TrainingDataMetadata;
}

interface TextLineWithLabels {
  text: string;
  bounding_box: [number, number, number, number]; // [x, y, w, h]
  confidence: number;
  line_index: number;
  elements: TextElement[];
  
  // ML学習用フィールド（自動生成）
  label: string;              // 'MERCHANT_NAME', 'TOTAL', 'TAX', 'OTHER' etc.
  label_confidence: number;   // 擬似ラベル信頼度
  features: TextLineFeatures; // 20次元特徴量
  feature_vector: number[];   // 数値ベクトル [位置, テキスト特徴量]
}

// 保存条件: 信頼度0.7以上のみ
export async function saveRawTrainingData(
  receiptId: string,
  ocrResult: OCRResult,
  extractionResult: ExtractionResult
): Promise<string | null> {
  if (extractionResult.confidence < 0.7) return null;
  
  const fileName = `receipt_${receiptId}_${Date.now()}.json`;
  const filePath = `./data/training/raw/${fileName}`;
  
  const trainingData = {
    receipt_id: receiptId,
    timestamp: new Date().toISOString(),
    is_verified: false,
    text_lines: generateTextLinesWithLabels(ocrResult, extractionResult),
    extraction_result: extractionResult,
    metadata: {
      image_path: imagePath,
      language: ocrResult.detected_language,
      ocr_confidence: ocrResult.confidence,
      extraction_confidence: extractionResult.confidence,
      is_verified: false
    }
  };
  
  await fs.writeFile(filePath, JSON.stringify(trainingData, null, 2));
  return fileName;
}
```

##### **B. Verified Training Data出力**
```typescript
// 手動修正後の検証済みデータをJSONファイルに保存（data/training/verified/）
interface VerifiedTrainingData {
  receipt_id: string;
  timestamp: string;
  is_verified: true;            // Ground truth
  text_lines: TextLineWithLabels[];
  extraction_result: {
    success: true;
    confidence: 1.0;            // 検証済みは常に1.0
    extracted_data: Record<string, any>; // 修正済みデータ
    metadata: {
      parsing_method: 'user_verified';
      is_ground_truth: true;
      document_type?: string;
      document_type_confidence?: number;
    };
  };
  metadata: {
    image_path: string;
    language: string;
    is_verified: true;
    verified_at: string;
  };
}

export async function saveVerifiedTrainingData(
  receiptId: string,
  ocrResult: OCRResult,
  correctedData: Record<string, any> // ユーザーが修正したデータ
): Promise<string | null> {
  const fileName = `verified_receipt_${receiptId}_${Date.now()}.json`;
  const filePath = `./data/training/verified/${fileName}`;
  
  const trainingData = {
    receipt_id: receiptId,
    timestamp: new Date().toISOString(),
    is_verified: true,
    text_lines: generateVerifiedLabels(ocrResult, correctedData), // 正解ラベル生成
    extraction_result: {
      success: true,
      confidence: 1.0,
      extracted_data: correctedData,
      metadata: { parsing_method: 'user_verified', is_ground_truth: true }
    },
    metadata: {
      image_path: imagePath,
      language: ocrResult.detected_language,
      is_verified: true,
      verified_at: new Date().toISOString()
    }
  };
  
  await fs.writeFile(filePath, JSON.stringify(trainingData, null, 2));
  return fileName;
}
```

##### **C. フォルダ構造**
```bash
data/training/
├── raw/                    # 自動抽出結果（信頼度0.7+）
│   ├── receipt_uuid1_timestamp.json
│   ├── receipt_uuid2_timestamp.json
│   └── ...
├── verified/              # 検証済みground truth
│   ├── verified_receipt_uuid1_timestamp.json  
│   ├── verified_receipt_uuid2_timestamp.json
│   └── ...
└── exports/               # ML用統合エクスポート
    ├── training_dataset.json      # 全データ統合
    ├── training_statistics.json   # 統計情報
    └── label_distribution.json    # ラベル分布
```

#### 4.2.1 データベース設計
```sql
-- 処理ジョブテーブル
CREATE TABLE processing_jobs (
  id UUID PRIMARY KEY,
  image_path TEXT NOT NULL,
  status TEXT NOT NULL,  -- pending, processing, completed, failed
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- OCR結果テーブル  
CREATE TABLE ocr_results (
  id UUID PRIMARY KEY,
  job_id UUID REFERENCES processing_jobs(id),
  full_text TEXT,
  text_lines JSONB,      -- TextLine[]
  confidence FLOAT,
  detected_language TEXT,
  processing_time INTEGER
);

-- 抽出結果テーブル
CREATE TABLE extraction_results (
  id UUID PRIMARY KEY,
  job_id UUID REFERENCES processing_jobs(id),
  extracted_data JSONB,  -- ExtractionResult
  confidence FLOAT,
  needs_verification BOOLEAN,
  is_verified BOOLEAN DEFAULT FALSE,
  verified_at TIMESTAMPTZ,
  verified_data JSONB    -- ユーザー修正データ
);

-- 学習データテーブル
CREATE TABLE training_data (
  id UUID PRIMARY KEY,
  job_id UUID REFERENCES processing_jobs(id),
  raw_data JSONB,        -- 生データ
  verified_data JSONB,   -- 検証済みデータ
  features JSONB,        -- 特徴量ベクトル
  labels JSONB,          -- ラベルデータ
  is_ground_truth BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 4.2.2 手動修正・検証システム（JSON出力統合）

##### **A. 編集インターフェース**
```typescript
// 修正可能フィールド
interface EditableFields {
  // 基本情報
  merchant_name: string;
  date: string;                    // ISO 8601
  currency: string;
  
  // 金額情報
  subtotal?: number;
  tax_total?: number;
  total: number;                   // 必須
  
  // 文書分類
  document_type: 'receipt' | 'invoice' | 'unknown';
  
  // Receipt特有
  payment_method?: string;
  transaction_id?: string;
  
  // Invoice特有
  due_date?: string;
  payment_terms?: string;
  bill_to_name?: string;
  bill_to_address?: string;
  
  // 商品情報
  items?: ReceiptItem[];
}

// 修正UIコンポーネント
export function EditableResultsForm({ 
  originalData, 
  onSave 
}: {
  originalData: ExtractionResult;
  onSave: (correctedData: EditableFields) => void;
}) {
  const [formData, setFormData] = useState<EditableFields>(originalData);
  const [isDirty, setIsDirty] = useState(false);
  
  const handleSave = async () => {
    // 1. 修正データの検証
    const validationErrors = validateCorrectedData(formData);
    if (validationErrors.length > 0) {
      showValidationErrors(validationErrors);
      return;
    }
    
    // 2. Verified Training Data保存
    await saveVerifiedTrainingData(
      originalData.receiptId,
      originalData.ocrResult, 
      formData
    );
    
    // 3. データベース更新
    await updateExtractionResult(originalData.jobId, {
      verifiedData: formData,
      isVerified: true,
      verifiedAt: new Date()
    });
    
    onSave(formData);
  };
  
  return (
    <Form>
      {/* 差分ハイライト表示 */}
      <DifferenceHighlight 
        original={originalData.extractedData}
        modified={formData}
      />
      
      {/* 編集フォーム */}
      <EditableField 
        label="Document Type"
        value={formData.document_type}
        onChange={(value) => setFormData({...formData, document_type: value})}
        options={['receipt', 'invoice', 'unknown']}
      />
      
      {/* 条件付きフィールド */}
      {formData.document_type === 'receipt' && (
        <ReceiptSpecificFields 
          data={formData} 
          onChange={setFormData} 
        />
      )}
      
      {formData.document_type === 'invoice' && (
        <InvoiceSpecificFields 
          data={formData} 
          onChange={setFormData} 
        />
      )}
      
      <Button onClick={handleSave} disabled={!isDirty}>
        Save Verified Data
      </Button>
    </Form>
  );
}
```

##### **B. 検証フロー（Flutter準拠）**
```typescript
// 1. 修正 → 2. 確認 → 3. 保存
export class VerificationWorkflow {
  
  async processVerification(
    jobId: string,
    correctedData: EditableFields
  ): Promise<VerificationResult> {
    
    // Step 1: データ検証
    const validation = await this.validateData(correctedData);
    if (!validation.isValid) {
      return { success: false, errors: validation.errors };
    }
    
    // Step 2: 整合性チェック
    const consistencyCheck = await this.checkConsistency(correctedData);
    if (!consistencyCheck.isConsistent) {
      // 警告表示但允许继续
      console.warn('Consistency issues:', consistencyCheck.warnings);
    }
    
    // Step 3: Verified JSON保存
    const verifiedJsonPath = await saveVerifiedTrainingData(
      jobId,
      correctedData.ocrResult,
      correctedData
    );
    
    // Step 4: データベース更新
    await prisma.extractionResult.update({
      where: { jobId },
      data: {
        verifiedData: JSON.stringify(correctedData),
        isVerified: true,
        verifiedAt: new Date(),
        // 文書分類情報更新
        documentType: correctedData.document_type,
        documentTypeConfidence: 1.0, // 手動確認済み
        documentTypeReason: 'user_verified'
      }
    });
    
    // Step 5: 統計更新
    await this.updateTrainingDataStats();
    
    return { 
      success: true, 
      verifiedJsonPath,
      updatedRecord: jobId 
    };
  }
  
  private async validateData(data: EditableFields): Promise<ValidationResult> {
    const errors: string[] = [];
    
    // 必須フィールドチェック
    if (!data.merchant_name) errors.push('Merchant name is required');
    if (!data.date) errors.push('Date is required');
    if (!data.total) errors.push('Total amount is required');
    if (!data.currency) errors.push('Currency is required');
    if (!data.document_type) errors.push('Document type is required');
    
    // 文書タイプ別検証
    if (data.document_type === 'invoice') {
      if (!data.due_date) errors.push('Due date required for invoices');
      if (!data.payment_terms) errors.push('Payment terms required for invoices');
    }
    
    return { isValid: errors.length === 0, errors };
  }
}
```

##### **C. 差分表示機能**
```typescript
// 自動抽出 vs 手動修正の差分可視化
export function DifferenceHighlight({ 
  original, 
  modified 
}: {
  original: ExtractionResult;
  modified: EditableFields;
}) {
  const differences = calculateDifferences(original, modified);
  
  return (
    <div className="difference-view">
      {differences.map((diff, index) => (
        <div 
          key={index} 
          className={`field-diff ${diff.type}`} // added, removed, modified
        >
          <span className="field-name">{diff.field}:</span>
          
          {diff.type === 'modified' && (
            <>
              <span className="original-value line-through">
                {diff.originalValue}
              </span>
              <span className="arrow">→</span>
              <span className="new-value text-green-600">
                {diff.newValue}
              </span>
            </>
          )}
          
          {diff.type === 'added' && (
            <span className="new-value text-green-600">
              + {diff.newValue}
            </span>
          )}
          
          {diff.type === 'removed' && (
            <span className="removed-value text-red-600">
              - {diff.originalValue}
            </span>
          )}
        </div>
      ))}
    </div>
  );
}
```

#### 4.2.3 学習データ統計・監視
```typescript
// 学習データ品質監視
interface TrainingDataStatistics {
  summary: {
    total_raw_samples: number;
    total_verified_samples: number;
    verification_rate: number;        // verified / (raw + verified)
    average_confidence: number;
    data_quality_score: number;       // 0.0-1.0
  };
  
  distribution: {
    by_language: Record<string, number>;
    by_document_type: Record<string, number>;
    by_confidence_range: {
      high: number;    // 0.8+
      medium: number;  // 0.5-0.8
      low: number;     // <0.5
    };
  };
  
  label_quality: {
    label_distribution: Record<string, number>;
    most_corrected_fields: string[];  // 最も修正が多いフィールド
    error_patterns: string[];          // よくある間違いパターン
  };
  
  progress_tracking: {
    target_samples: number;            // 目標サンプル数
    current_samples: number;
    completion_percentage: number;
    estimated_completion_date: string;
  };
}

export async function generateTrainingDataStats(): Promise<TrainingDataStatistics> {
  // Raw データ分析
  const rawFiles = await glob('./data/training/raw/*.json');
  const rawData = await Promise.all(
    rawFiles.map(async file => JSON.parse(await fs.readFile(file, 'utf8')))
  );
  
  // Verified データ分析
  const verifiedFiles = await glob('./data/training/verified/*.json');
  const verifiedData = await Promise.all(
    verifiedFiles.map(async file => JSON.parse(await fs.readFile(file, 'utf8')))
  );
  
  // 統計計算
  const stats: TrainingDataStatistics = {
    summary: {
      total_raw_samples: rawData.length,
      total_verified_samples: verifiedData.length,
      verification_rate: verifiedData.length / (rawData.length + verifiedData.length),
      average_confidence: calculateAverageConfidence(rawData, verifiedData),
      data_quality_score: calculateQualityScore(rawData, verifiedData)
    },
    distribution: {
      by_language: calculateLanguageDistribution(rawData, verifiedData),
      by_document_type: calculateDocumentTypeDistribution(rawData, verifiedData),
      by_confidence_range: calculateConfidenceDistribution(rawData)
    },
    label_quality: {
      label_distribution: calculateLabelDistribution(rawData, verifiedData),
      most_corrected_fields: findMostCorrectedFields(rawData, verifiedData),
      error_patterns: analyzeErrorPatterns(rawData, verifiedData)
    },
    progress_tracking: {
      target_samples: 1000,  // 目標
      current_samples: rawData.length + verifiedData.length,
      completion_percentage: (rawData.length + verifiedData.length) / 1000 * 100,
      estimated_completion_date: estimateCompletionDate(rawData, verifiedData)
    }
  };
  
  // 統計ファイル出力
  await fs.writeFile(
    './data/training/exports/training_statistics.json',
    JSON.stringify(stats, null, 2)
  );
  
  return stats;
}

// ダッシュボード用API
export async function getTrainingProgress(): Promise<{
  needsAttention: string[];
  recommendations: string[];
  dataQuality: 'good' | 'warning' | 'poor';
}> {
  const stats = await generateTrainingDataStats();
  const needsAttention = [];
  const recommendations = [];
  
  // 品質チェック
  if (stats.summary.verification_rate < 0.3) {
    needsAttention.push('Low verification rate (< 30%)');
    recommendations.push('Increase manual verification efforts');
  }
  
  if (stats.summary.data_quality_score < 0.7) {
    needsAttention.push('Data quality below threshold');
    recommendations.push('Review and improve extraction accuracy');
  }
  
  // 言語バランスチェック
  const languages = Object.values(stats.distribution.by_language);
  const maxLanguageSamples = Math.max(...languages);
  const minLanguageSamples = Math.min(...languages);
  if (maxLanguageSamples / minLanguageSamples > 3) {
    needsAttention.push('Imbalanced language distribution');
    recommendations.push('Collect more samples for underrepresented languages');
  }
  
  // データ品質判定
  let dataQuality: 'good' | 'warning' | 'poor';
  if (stats.summary.data_quality_score >= 0.8) {
    dataQuality = 'good';
  } else if (stats.summary.data_quality_score >= 0.6) {
    dataQuality = 'warning';
  } else {
    dataQuality = 'poor';
  }
  
  return { needsAttention, recommendations, dataQuality };
}
```

#### 4.2.4 機械学習用データエクスポート（最終形）
```typescript
interface TrainingDataExport {
  receipt_id: string;
  timestamp: string;
  is_verified: boolean;
  text_lines: Array<{
    text: string;
    bounding_box: number[];
    confidence: number;
    label: string;           // MERCHANT_NAME, DATE, TOTAL, etc.
    label_confidence: number;
    features: FeatureVector; // 特徴量
    feature_vector: number[];
  }>;
  extraction_result: ExtractionResult;
  metadata: {
    image_path: string;
    language: string;
    ocr_confidence: number;
    extraction_confidence: number;
    is_ground_truth: boolean;
  };
}
```

### 4.3 Phase 3: 機械学習パイプライン

#### 4.3.1 特徴量エンジニアリング
```python
# Flutter TextLineFeatures ポート
class TextLineFeatures:
    # 位置特徴量 (4)
    x_center: float
    y_center: float  
    width: float
    height: float
    
    # 位置フラグ (4)
    is_right_side: bool
    is_bottom_area: bool
    is_middle_section: bool
    line_index_norm: float
    
    # テキスト特徴量 (12)
    has_currency_symbol: bool
    has_percent: bool
    has_amount_like: bool
    has_total_keyword: bool
    has_tax_keyword: bool
    has_subtotal_keyword: bool
    has_date_like: bool
    has_quantity_marker: bool
    has_item_like: bool
    digit_count: int
    alpha_count: int
    contains_colon: bool
    
    # 特徴量ベクトル生成
    def to_vector(self) -> List[float]:
        return [
            self.x_center, self.y_center, self.width, self.height,
            float(self.is_right_side), float(self.is_bottom_area),
            float(self.is_middle_section), self.line_index_norm,
            float(self.has_currency_symbol), float(self.has_percent),
            float(self.has_amount_like), float(self.has_total_keyword),
            float(self.has_tax_keyword), float(self.has_subtotal_keyword),
            float(self.has_date_like), float(self.has_quantity_marker),
            float(self.has_item_like), self.digit_count / 100.0,
            self.alpha_count / 100.0, float(self.contains_colon)
        ]
```

#### 4.3.2 モデルアーキテクチャ
```python
# マルチタスク学習モデル（文書分類 + シーケンスラベリング）
class DocumentExtractionModel:
    def __init__(self):
        self.bert_model = AutoModel.from_pretrained('bert-base-multilingual')
        
        # 特徴量MLP
        self.feature_mlp = nn.Sequential(
            nn.Linear(20, 64),  # 特徴量次元
            nn.ReLU(),
            nn.Dropout(0.1)
        )
        
        # 文書分類ヘッド
        self.document_classifier = nn.Sequential(
            nn.Linear(768, 256),
            nn.ReLU(),
            nn.Dropout(0.1),
            nn.Linear(256, 3)  # receipt, invoice, unknown
        )
        
        # フィールド抽出ヘッド
        self.field_classifier = nn.Linear(768 + 64, num_labels)  # BERT + features
        
    def forward(self, input_ids, features, attention_mask):
        bert_output = self.bert_model(input_ids, attention_mask=attention_mask)
        
        # 文書分類（[CLS]トークン使用）
        cls_output = bert_output.last_hidden_state[:, 0, :]  # [CLS]
        doc_type_logits = self.document_classifier(cls_output)
        
        # フィールド抽出（シーケンスラベリング）
        feature_output = self.feature_mlp(features)
        combined = torch.cat([bert_output.last_hidden_state, feature_output], dim=-1)
        field_logits = self.field_classifier(combined)
        
        return {
            'document_type_logits': doc_type_logits,
            'field_logits': field_logits
        }

# 文書タイプラベル
DOCUMENT_TYPES = ['receipt', 'invoice', 'unknown']

# フィールドラベル（文書タイプごとに拡張）
FIELD_LABELS = [
    'OTHER', 'MERCHANT_NAME', 'DATE', 'TIME',
    'SUBTOTAL', 'TAX', 'TOTAL', 
    'RECEIPT_NUMBER', 'ITEM_NAME', 'ITEM_PRICE',
    # Receipt特有
    'PAYMENT_METHOD', 'TRANSACTION_ID',
    # Invoice特有  
    'DUE_DATE', 'PAYMENT_TERMS', 'BILL_TO', 'INVOICE_NUMBER'
]
```

#### 4.3.3 学習パイプライン
```python
# 学習データローダー
class ReceiptDataset(Dataset):
    def __init__(self, training_data_files):
        self.data = []
        for file_path in training_data_files:
            with open(file_path) as f:
                receipt_data = json.load(f)
                self.data.append(self._process_receipt(receipt_data))
    
    def _process_receipt(self, receipt_data):
        text_lines = receipt_data['text_lines']
        return {
            'texts': [line['text'] for line in text_lines],
            'features': [line['feature_vector'] for line in text_lines],
            'labels': [line['label'] for line in text_lines],
            'is_verified': receipt_data['is_verified']
        }

# 学習ループ
def train_model(model, train_loader, val_loader, epochs=10):
    optimizer = AdamW(model.parameters(), lr=2e-5)
    scheduler = get_linear_schedule_with_warmup(
        optimizer, num_warmup_steps=0, num_training_steps=len(train_loader) * epochs
    )
    
    for epoch in range(epochs):
        model.train()
        for batch in train_loader:
            outputs = model(**batch)
            loss = outputs.loss
            loss.backward()
            optimizer.step()
            scheduler.step()
            optimizer.zero_grad()
```

#### 4.3.4 評価・最適化
```python
# 評価メトリクス
def evaluate_model(model, val_loader):
    model.eval()
    predictions = []
    true_labels = []
    
    with torch.no_grad():
        for batch in val_loader:
            outputs = model(**batch)
            predictions.extend(torch.argmax(outputs.logits, dim=-1).cpu().numpy())
            true_labels.extend(batch['labels'].cpu().numpy())
    
    # フィールド別精度
    field_scores = {}
    for label in LABELS:
        precision = precision_score(true_labels, predictions, 
                                   labels=[LABELS.index(label)], average='macro')
        recall = recall_score(true_labels, predictions,
                             labels=[LABELS.index(label)], average='macro')  
        f1 = f1_score(true_labels, predictions,
                      labels=[LABELS.index(label)], average='macro')
        field_scores[label] = {'precision': precision, 'recall': recall, 'f1': f1}
    
    return field_scores

# ハイパーパラメータ最適化
def optimize_hyperparameters():
    study = optuna.create_study(direction='maximize')
    study.optimize(objective, n_trials=50)
    return study.best_params
```

### 4.4 Phase 4: 高精度抽出API

#### 4.4.1 API設計
```python
# FastAPI エンドポイント
from fastapi import FastAPI, File, UploadFile
import uvicorn

app = FastAPI()

@app.post("/api/v1/extract")
async def extract_receipt(
    file: UploadFile = File(...),
    language_hint: str = "auto"
):
    # 1. OCR処理
    ocr_result = await ocr_service.process_image(file)
    
    # 2. ML推論
    ml_predictions = await ml_service.predict(ocr_result)
    
    # 3. ルールベース後処理
    extraction_result = await extraction_service.extract(
        ocr_result, ml_predictions
    )
    
    # 4. 整合性チェック
    validated_result = await validation_service.validate(extraction_result)
    
    return {
        "job_id": str(uuid4()),
        "status": "completed",
        "ocr_result": ocr_result,
        "extraction_result": validated_result,
        "confidence": validated_result.confidence,
        "processing_time": time.time() - start_time
    }

@app.get("/api/v1/jobs/{job_id}")  
async def get_job_result(job_id: str):
    # ジョブ結果取得
    pass
```

#### 4.4.2 モデルサービング
```python
# モデル推論サービス
class MLExtractionService:
    def __init__(self, model_path: str):
        self.model = torch.load(model_path)
        self.tokenizer = AutoTokenizer.from_pretrained('bert-base-multilingual')
        
    async def predict(self, ocr_result: OCRResult) -> Dict[str, Any]:
        # 特徴量抽出
        features = self._extract_features(ocr_result.text_lines)
        
        # トークン化
        tokens = self.tokenizer(
            [line.text for line in ocr_result.text_lines],
            padding=True, truncation=True, return_tensors='pt'
        )
        
        # 推論
        with torch.no_grad():
            predictions = self.model(
                input_ids=tokens['input_ids'],
                features=torch.tensor(features),
                attention_mask=tokens['attention_mask']
            )
        
        # 後処理
        return self._post_process_predictions(predictions, ocr_result)
```

#### 4.4.3 統合後処理
```typescript
// ルールベース + ML統合
class HybridExtractionService {
  async extract(ocrResult: OCRResult, mlPredictions: MLPredictions): Promise<ExtractionResult> {
    // 1. MLモデルによるフィールド抽出
    const mlFields = this.extractFieldsFromML(mlPredictions);
    
    // 2. ルールベース抽出（フォールバック）
    const ruleFields = await this.ruleBasedExtraction(ocrResult);
    
    // 3. 信頼度による統合
    const mergedFields = this.mergeResults(mlFields, ruleFields);
    
    // 4. 整合性チェック
    const validatedFields = await this.validateConsistency(mergedFields);
    
    return {
      ...validatedFields,
      confidence: this.calculateOverallConfidence(mergedFields),
      needs_verification: validatedFields.confidence < 0.7,
      status: validatedFields.confidence >= 0.7 ? 'completed' : 'needs_verification'
    };
  }
}
```

---

## 5. 開発ロードマップ

### 5.1 Phase 1: Web基盤構築 (4週間)
**Week 1-2: プロジェクトセットアップ**
- [ ] Next.js 14 + TypeScript プロジェクト作成
- [ ] PostgreSQL + Prisma セットアップ
- [ ] 基本UI/UXデザイン実装
- [ ] 画像アップロード機能

**Week 3-4: OCR統合**
- [ ] Google Cloud Vision API 統合
- [ ] Flutter OCRResult形式へのポート
- [ ] 基本抽出ロジック移植
- [ ] 結果表示UI実装

### 5.2 Phase 2: データ収集システム (3週間)  
**Week 5-6: CRUD機能**
- [ ] データベーススキーマ実装
- [ ] 処理ジョブ管理API
- [ ] OCR/抽出結果保存機能
- [ ] 管理画面UI

**Week 7: 手動修正システム**
- [ ] 編集可能なフォーム実装
- [ ] 差分表示機能
- [ ] 検証ワークフロー
- [ ] データエクスポート機能

### 5.3 Phase 3: ML開発 (6週間)
**Week 8-10: 学習パイプライン構築**
- [ ] Python環境 + FastAPI セットアップ
- [ ] 特徴量抽出モジュール移植
- [ ] データローダー実装
- [ ] ベースラインモデル訓練

**Week 11-12: モデル最適化**
- [ ] ハイパーパラメータ調整
- [ ] クロスバリデーション
- [ ] 評価メトリクス実装
- [ ] モデル性能分析

**Week 13: モデルサービング**
- [ ] 推論API実装
- [ ] Docker化
- [ ] パフォーマンステスト
- [ ] 本番デプロイ準備

### 5.4 Phase 4: 統合・最適化 (3週間)
**Week 14-15: API統合** 
- [ ] ML + ルールベース統合
- [ ] エンドツーエンドテスト
- [ ] Flutter連携テスト
- [ ] パフォーマンス最適化

**Week 16: 最終調整**
- [ ] UI/UX改善
- [ ] エラーハンドリング強化
- [ ] ドキュメント作成
- [ ] 本番リリース

---

## 6. 品質保証・評価基準

### 6.1 OCR品質基準
- **精度目標**: 95%以上の文字認識精度
- **処理時間**: 2秒以内（1000x1000px画像）
- **言語対応**: EN/FI/SV/FR/DE/IT/ES

### 6.2 抽出精度目標
- **文書分類精度**: 95%以上（Receipt/Invoice分類）
- **必須フィールド**: 95%以上（document_type, merchant_name, date, total, currency）
- **Receipt特有フィールド**: 90%以上（payment_method, transaction_id）
- **Invoice特有フィールド**: 90%以上（due_date, payment_terms, bill_to）
- **オプションフィールド**: 85%以上（subtotal, tax, items）
- **整合性チェック**: 誤差±0.02以下

### 6.3 学習データ品質
- **検証済みデータ**: 1,000件以上のground truth
- **多様性**: 各言語200件以上、多様なレシート形式
- **ラベル品質**: Inter-annotator agreement 95%以上

### 6.4 API性能要件
- **レスポンス時間**: 3秒以内（OCR+抽出）
- **同時接続**: 100リクエスト/分
- **可用性**: 99.9%以上

---

## 7. リスク・制約事項

### 7.1 技術リスク
- **OCR精度**: 手書き・低品質画像での精度低下
- **多言語対応**: 言語間での性能差
- **モデル汎化**: 学習データの偏りによる過学習

### 7.2 対応策
- **データ拡張**: 人工的なノイズ・歪み追加
- **アクティブラーニング**: 不確実性の高いサンプルの優先ラベリング
- **継続学習**: 新しいデータでのモデル更新

### 7.3 制約事項
- **学習データ**: プライバシー保護（個人情報マスク化）
- **計算資源**: GPU環境での学習・推論
- **運用コスト**: クラウドAPIコストの管理

---

## 8. 参考実装ファイル

### 8.1 Flutter参考コード
```
receipt-scanner/flutter_app/lib/
├── services/
│   ├── ocr/ml_kit_service.dart              # OCR実装
│   ├── extraction/receipt_parser.dart       # 抽出ロジック  
│   └── training_data/training_data_collector.dart  # 学習データ収集
├── presentation/screens/
│   └── preview/preview_screen.dart          # UI実装
└── data/models/
    ├── receipt.dart                         # データモデル
    └── processing_result.dart               # 結果モデル
```

### 8.2 重要機能の移植マッピング
| Flutter | Web版 | 備考 |
|---|---|---|
| ML Kit OCR | Google Cloud Vision | API統合 |
| ReceiptParser | HybridExtractionService | ルール+ML |
| TrainingDataCollector | TrainingDataAPI | PostgreSQL保存 |
| PreviewScreen | EditableResultsUI | React実装 |
| TextLineFeatures | FeatureExtractor | Python移植 |

---

## 9. 成功指標・KPI

### 9.1 開発KPI
- [ ] 16週間以内の開発完了
- [ ] 全機能の単体・統合テスト100%実装
- [ ] コードカバレッジ90%以上

### 9.2 品質KPI  
- [ ] 抽出精度95%以上（主要フィールド）
- [ ] エンドツーエンド処理時間3秒以内
- [ ] 1,000件以上の高品質学習データ収集

### 9.3 運用KPI
- [ ] 月間1,000レシート処理能力
- [ ] 99.9%システム稼働率
- [ ] ユーザー満足度90%以上

---

この要件定義書に基づいて、FlutterアプリケーションのOCR・抽出機能をWeb版に移植し、機械学習システムと統合することで、高精度で実用的なレシート処理システムを構築する。