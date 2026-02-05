import 'package:json_annotation/json_annotation.dart';

part 'gmail_extracted_invoice.g.dart';

/// Status of an extracted invoice
enum ExtractedInvoiceStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('rejected')
  rejected,
  @JsonValue('skipped')
  skipped, // Scanned but not an invoice (won't be re-scanned)
}

/// Source type of the extracted invoice
enum InvoiceSourceType {
  @JsonValue('attachment')
  attachment,
  @JsonValue('email_body')
  emailBody,
}

/// Represents an invoice extracted from Gmail
@JsonSerializable()
class GmailExtractedInvoice {
  final String id;

  @JsonKey(name: 'user_id')
  final String userId;

  @JsonKey(name: 'gmail_message_id')
  final String gmailMessageId;

  @JsonKey(name: 'email_subject')
  final String? emailSubject;

  @JsonKey(name: 'email_from')
  final String? emailFrom;

  @JsonKey(name: 'email_date')
  final DateTime? emailDate;

  @JsonKey(name: 'source_type')
  final InvoiceSourceType sourceType;

  @JsonKey(name: 'attachment_filename')
  final String? attachmentFilename;

  // Invoice fields
  @JsonKey(name: 'merchant_name')
  final String? merchantName;

  @JsonKey(name: 'vendor_address')
  final String? vendorAddress;

  @JsonKey(name: 'vendor_tax_id')
  final String? vendorTaxId;

  @JsonKey(name: 'customer_name')
  final String? customerName;

  @JsonKey(name: 'invoice_number')
  final String? invoiceNumber;

  @JsonKey(name: 'invoice_date')
  final DateTime? invoiceDate;

  @JsonKey(name: 'due_date')
  final DateTime? dueDate;

  final double? subtotal;

  @JsonKey(name: 'tax_total')
  final double? taxTotal;

  @JsonKey(name: 'total_amount')
  final double? totalAmount;

  final String currency;
  final double? confidence;

  @JsonKey(name: 'raw_extracted_data')
  final Map<String, dynamic>? rawExtractedData;

  @JsonKey(name: 'original_file_url')
  final String? originalFileUrl;

  // Status
  final ExtractedInvoiceStatus status;

  @JsonKey(name: 'invoice_id')
  final String? invoiceId; // ID in invoices table after approval

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  GmailExtractedInvoice({
    required this.id,
    required this.userId,
    required this.gmailMessageId,
    this.emailSubject,
    this.emailFrom,
    this.emailDate,
    required this.sourceType,
    this.attachmentFilename,
    this.merchantName,
    this.vendorAddress,
    this.vendorTaxId,
    this.customerName,
    this.invoiceNumber,
    this.invoiceDate,
    this.dueDate,
    this.subtotal,
    this.taxTotal,
    this.totalAmount,
    this.currency = 'EUR',
    this.confidence,
    this.rawExtractedData,
    this.originalFileUrl,
    this.status = ExtractedInvoiceStatus.pending,
    this.invoiceId,
    required this.createdAt,
  });

  factory GmailExtractedInvoice.fromJson(Map<String, dynamic> json) =>
      _$GmailExtractedInvoiceFromJson(json);

  Map<String, dynamic> toJson() => _$GmailExtractedInvoiceToJson(this);

  GmailExtractedInvoice copyWith({
    String? id,
    String? userId,
    String? gmailMessageId,
    String? emailSubject,
    String? emailFrom,
    DateTime? emailDate,
    InvoiceSourceType? sourceType,
    String? attachmentFilename,
    String? merchantName,
    String? vendorAddress,
    String? vendorTaxId,
    String? customerName,
    String? invoiceNumber,
    DateTime? invoiceDate,
    DateTime? dueDate,
    double? subtotal,
    double? taxTotal,
    double? totalAmount,
    String? currency,
    double? confidence,
    Map<String, dynamic>? rawExtractedData,
    String? originalFileUrl,
    ExtractedInvoiceStatus? status,
    String? invoiceId,
    DateTime? createdAt,
  }) {
    return GmailExtractedInvoice(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gmailMessageId: gmailMessageId ?? this.gmailMessageId,
      emailSubject: emailSubject ?? this.emailSubject,
      emailFrom: emailFrom ?? this.emailFrom,
      emailDate: emailDate ?? this.emailDate,
      sourceType: sourceType ?? this.sourceType,
      attachmentFilename: attachmentFilename ?? this.attachmentFilename,
      merchantName: merchantName ?? this.merchantName,
      vendorAddress: vendorAddress ?? this.vendorAddress,
      vendorTaxId: vendorTaxId ?? this.vendorTaxId,
      customerName: customerName ?? this.customerName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      subtotal: subtotal ?? this.subtotal,
      taxTotal: taxTotal ?? this.taxTotal,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      confidence: confidence ?? this.confidence,
      rawExtractedData: rawExtractedData ?? this.rawExtractedData,
      originalFileUrl: originalFileUrl ?? this.originalFileUrl,
      status: status ?? this.status,
      invoiceId: invoiceId ?? this.invoiceId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if the extraction has high confidence
  bool get hasHighConfidence => (confidence ?? 0) >= 0.7;

  /// Get source type display name
  String get sourceTypeDisplay {
    switch (sourceType) {
      case InvoiceSourceType.attachment:
        return 'Attachment';
      case InvoiceSourceType.emailBody:
        return 'Email body';
    }
  }

  /// Get status display name
  String get statusDisplay {
    switch (status) {
      case ExtractedInvoiceStatus.pending:
        return 'Pending review';
      case ExtractedInvoiceStatus.approved:
        return 'Approved';
      case ExtractedInvoiceStatus.rejected:
        return 'Rejected';
      case ExtractedInvoiceStatus.skipped:
        return 'Skipped (not invoice)';
    }
  }

  /// Check if invoice can be edited (only pending invoices)
  bool get canEdit => status == ExtractedInvoiceStatus.pending;

  /// Check if invoice can be approved (only pending invoices)
  bool get canApprove => status == ExtractedInvoiceStatus.pending;

  /// Check if invoice can be rejected (only pending invoices)
  bool get canReject => status == ExtractedInvoiceStatus.pending;
}

/// State for extracted invoices list
class ExtractedInvoicesState {
  final List<GmailExtractedInvoice> invoices;
  final bool isLoading;
  final bool isProcessing; // For approve/reject operations
  final String? error;

  const ExtractedInvoicesState({
    this.invoices = const [],
    this.isLoading = false,
    this.isProcessing = false,
    this.error,
  });

  /// Get pending invoices count
  int get pendingCount =>
      invoices.where((i) => i.status == ExtractedInvoiceStatus.pending).length;

  ExtractedInvoicesState copyWith({
    List<GmailExtractedInvoice>? invoices,
    bool? isLoading,
    bool? isProcessing,
    String? error,
    bool clearError = false,
  }) {
    return ExtractedInvoicesState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
