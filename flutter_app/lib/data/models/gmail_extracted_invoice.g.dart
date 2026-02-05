// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gmail_extracted_invoice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GmailExtractedInvoice _$GmailExtractedInvoiceFromJson(
        Map<String, dynamic> json) =>
    GmailExtractedInvoice(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      gmailMessageId: json['gmail_message_id'] as String,
      emailSubject: json['email_subject'] as String?,
      emailFrom: json['email_from'] as String?,
      emailDate: json['email_date'] == null
          ? null
          : DateTime.parse(json['email_date'] as String),
      sourceType: $enumDecode(_$InvoiceSourceTypeEnumMap, json['source_type']),
      attachmentFilename: json['attachment_filename'] as String?,
      merchantName: json['merchant_name'] as String?,
      vendorAddress: json['vendor_address'] as String?,
      vendorTaxId: json['vendor_tax_id'] as String?,
      customerName: json['customer_name'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      invoiceDate: json['invoice_date'] == null
          ? null
          : DateTime.parse(json['invoice_date'] as String),
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      taxTotal: (json['tax_total'] as num?)?.toDouble(),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      confidence: (json['confidence'] as num?)?.toDouble(),
      rawExtractedData: json['raw_extracted_data'] as Map<String, dynamic>?,
      originalFileUrl: json['original_file_url'] as String?,
      status: $enumDecodeNullable(
              _$ExtractedInvoiceStatusEnumMap, json['status']) ??
          ExtractedInvoiceStatus.pending,
      invoiceId: json['invoice_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$GmailExtractedInvoiceToJson(
        GmailExtractedInvoice instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'gmail_message_id': instance.gmailMessageId,
      'email_subject': instance.emailSubject,
      'email_from': instance.emailFrom,
      'email_date': instance.emailDate?.toIso8601String(),
      'source_type': _$InvoiceSourceTypeEnumMap[instance.sourceType]!,
      'attachment_filename': instance.attachmentFilename,
      'merchant_name': instance.merchantName,
      'vendor_address': instance.vendorAddress,
      'vendor_tax_id': instance.vendorTaxId,
      'customer_name': instance.customerName,
      'invoice_number': instance.invoiceNumber,
      'invoice_date': instance.invoiceDate?.toIso8601String(),
      'due_date': instance.dueDate?.toIso8601String(),
      'subtotal': instance.subtotal,
      'tax_total': instance.taxTotal,
      'total_amount': instance.totalAmount,
      'currency': instance.currency,
      'confidence': instance.confidence,
      'raw_extracted_data': instance.rawExtractedData,
      'original_file_url': instance.originalFileUrl,
      'status': _$ExtractedInvoiceStatusEnumMap[instance.status]!,
      'invoice_id': instance.invoiceId,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$InvoiceSourceTypeEnumMap = {
  InvoiceSourceType.attachment: 'attachment',
  InvoiceSourceType.emailBody: 'email_body',
};

const _$ExtractedInvoiceStatusEnumMap = {
  ExtractedInvoiceStatus.pending: 'pending',
  ExtractedInvoiceStatus.approved: 'approved',
  ExtractedInvoiceStatus.rejected: 'rejected',
};
