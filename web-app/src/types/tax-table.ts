/**
 * Types for Tax Table Analysis and Detection
 */

import { TextLine } from './ocr';
import { EvidenceSource } from './evidence';

export interface TaxTable {
  id: string;
  header: TableHeader;
  rows: TaxTableRow[];
  totals: TableTotals;
  confidence: number;
  spatialInfo: TableSpatialInfo;
}

export interface TableHeader {
  line: TextLine;
  index: number;
  extractedRates: TaxRateMapping[];
  structure: ColumnStructure;
  confidence: number;
}

export interface TaxTableRow {
  code: string;           // "A", "B", "C"
  rate: number;           // 24, 14
  gross: number;          // 1.97, 33.65
  net: number;            // 1.59, 29.52
  tax: number;            // 0.38, 4.13
  confidence: number;
  lineIndex: number;
  validationResults: RowValidationResults;
}

export interface TableTotals {
  totalGross: number;
  totalNet: number;
  totalTax: number;
  calculatedFromRows: boolean;
  confidence: number;
}

export interface TableSpatialInfo {
  region: BoundingBox;
  headerLineIndex: number;
  dataLineIndices: number[];
  columnBoundaries: ColumnBoundary[];
}

export interface TaxRateMapping {
  rate: number;           // 24, 14
  category: string;       // "A", "B", "Standard", "Reduced"
  position: number;       // Column index or character position
  confidence: number;
}

export interface ColumnStructure {
  columns: Column[];
  confidence: number;
}

export interface Column {
  type: 'code' | 'rate' | 'gross' | 'net' | 'tax';
  xRange: [number, number];
  alignment: 'left' | 'right' | 'center';
  expectedFormat: RegExp;
}

export interface ColumnBoundary {
  start: number;
  end: number;
  taxRate?: number;
  columnType: 'category' | 'net' | 'tax' | 'gross';
}

export interface BoundingBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface RowValidationResults {
  mathConsistent: boolean;        // gross = net + tax
  rateConsistent: boolean;        // tax = net * rate / 100
  toleranceUsed: number;          // Tolerance used for validation
  discrepancy?: number;           // Amount of discrepancy if any
}

export interface ValidationResult {
  valid: boolean;
  confidence: number;
  errors: string[];
  warnings: string[];
}

export interface HeaderContext {
  rateDeclarations: RateDeclaration[];
  structureInfo: TableStructureInfo;
  mergedContext: ContextualRateInfo;
  confidence: number;
}

export interface RateDeclaration {
  rate: number;
  category: string;
  pattern: string;
  position: number;
  confidence: number;
}

export interface TableStructureInfo {
  columnCount: number;
  hasHeaders: boolean;
  dataRowPattern: RegExp;
  expectedStructure: string[];
}

export interface ContextualRateInfo {
  standardRates: number[];
  countryContext: string;
  inferredMappings: TaxRateMapping[];
}

// Tax Rate Detection Strategy Types
export interface TaxRateStandardization {
  mappedRates: Map<number, number>;
  confidence: number;
  country: string;
}

export interface InferredTaxRate {
  rate: number;
  source: 'calculation' | 'context' | 'template';
  confidence: number;
  rationale: string;
}

export interface TaxRateFeatures {
  merchantName: string;
  country: string;
  categoryCode: string;
  netAmount: number;
  taxAmount: number;
  calculatedRate: number;
  contextKeywords: string[];
}

export interface TaxRatePrediction {
  predictedRate: number;
  confidence: number;
  rationale: string;
}

// Template-based Detection Types
export interface ReceiptTemplatePattern {
  merchantPattern: RegExp;
  country: string;
  expectedTaxRates: number[];
  tableStructure: TableStructureTemplate;
}

export interface TableStructureTemplate {
  headerPatterns: string[];
  dataRowPattern: RegExp;
  columnMapping: {
    [columnIndex: number]: 'category' | 'net' | 'tax' | 'gross';
  };
  rateAssignment: {
    [categoryCode: string]: number;
  };
}

// Evidence Types for Tax Table
export interface TaxTableEvidence {
  source: EvidenceSource;
  field: 'subtotal' | 'tax_total' | 'tax_breakdown';
  data: {
    tableRows: TaxTableRow[];
    calculatedSubtotal: number;
    calculatedTaxTotal: number;
    taxBreakdown: TaxBreakdownItem[];
  };
  spatialInfo: TableSpatialInfo;
  confidence: number;
}

export interface TaxBreakdownItem {
  rate: number;
  amount: number;
  net: number;
  category?: string;
}

// Constants for validation
export const TAX_VALIDATION_TOLERANCES = {
  MATH_TOLERANCE: 0.02,        // 2 cents tolerance for rounding
  RATE_TOLERANCE: 0.5,         // 0.5% tolerance for rate matching
  SPATIAL_Y_TOLERANCE: 15      // 15 pixels for line grouping
} as const;

// Standard tax rates by country
export const COUNTRY_TAX_RATES = {
  FI: { standard: 24, reduced: [14, 10], zero: 0 },     // Finland
  SE: { standard: 25, reduced: [12, 6], zero: 0 },      // Sweden
  DE: { standard: 19, reduced: [7], zero: 0 },          // Germany
  US: { standard: 0, reduced: [], zero: 0 },            // US (varies by state)
  GB: { standard: 20, reduced: [5], zero: 0 }           // UK
} as const;